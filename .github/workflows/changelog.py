import subprocess
import json
import os
import tempfile
import time
from typing import Any
import re
from collections import defaultdict

"""
This script has been made by the guys at Universal Blue / Bazzite - I don't take any credit for it, I just made some adjustments to fit my needs. You can find the original script here: https://github.com/bazzite/bazzite/blob/main/scripts/changelog.py
"""


IMAGE = "ghcr.io/themimolet/mimos"

RETRIES = 3
RETRY_WAIT = 5
FEDORA_PATTERN = re.compile(r"\.fc\d\d")
EPOCH_PATTERN = re.compile(r"^\d+:")
STABLE_START_PATTERN = re.compile(r"\d\d\.\d")
OTHER_START_PATTERN = lambda target: re.compile(rf"{target}-\d\d\.\d")

PATTERN_ADD = "\n| Added | {name} | - | {version} |"
PATTERN_CHANGE = "\n| Changed | {name} | {prev} | {new} |"
PATTERN_REMOVE = "\n| Removed | {name} | {version} | - |"
PATTERN_PKGREL_CHANGED = "{prev} → {new}"
PATTERN_PKGREL = "{version}"
COMMON_PAT = "### Changes\n| - | Name | Previous | New |\n| --- | --- | --- | --- |{changes}\n\n"

COMMITS_FORMAT = (
    "### Commits\n| Hash | Subject | Author |\n| --- | --- | --- |{commits}\n\n"
)
COMMIT_FORMAT = "\n| **[{short}](https://github.com/themimolet/mimos/commit/{hash})** | {subject} | {author} |"

CHANGELOG_TITLE = "{tag}: {pretty}"
CHANGELOG_FORMAT = """\
{handwritten}

From previous `{target}` version `{prev}` there have been the following changes. **One package per new version shown.**

### Major packages
| Name | Version |
| --- | --- |
| **Kernel** | {pkgrel:kernel} |
| **Firmware** | {pkgrel:atheros-firmware} |
| **KDE** | {pkgrel:plasma-desktop} |
| **Mesa** | {pkgrel:mesa-filesystem} |
| **Nvidia** | {pkgrel:nvidia-kmod-common} |
| **Gamescope** | {pkgrel:terra-gamescope} |
| **Bazaar** | {pkgrel:bazaar} |
| **LibreOffice** | {pkgrel:libreoffice} |
| **Helium** | {pkgrel:helium-bin} |

{changes}

### How to rebase
For current users, type the following to rebase to this version:

# For this branch (if latest):

```
sudo bootc switch --enforce-container-sigpolicy ghcr.io/themimolet/mimos:latest
```

# For this specific image:

```
sudo bootc switch --enforce-container-sigpolicy ghcr.io/themimolet/mimos:{curr}
```
"""
HANDWRITTEN_PLACEHOLDER = """\
This is an automatically generated changelog for release `{curr}`.
"""

BLACKLIST_VERSIONS = [
    "kernel",
    "mesa-filesystem",
    "terra-gamescope",
    "gamescope-session",
    "inputplumber",
    "powerstation",
    "steamos-manager-powerstation",
    "opengamepadui",
    "bazaar",
    "plasma-desktop",
    "atheros-firmware",
    "nvidia-kmod-common",
    "libreoffice",
    "helium-bin"
]

def get_manifests(target: str):
    output = None
    print(f"Getting {IMAGE}:{target} manifest.")
    for i in range(RETRIES):
        try:
            output = subprocess.run(
                ["skopeo", "inspect", f"docker://{IMAGE}:{target}"],
                check=True,
                stdout=subprocess.PIPE,
            ).stdout
            break
        except subprocess.CalledProcessError:
            print(
                f"Failed to get {IMAGE}:{target}, retrying in {RETRY_WAIT} seconds ({i+1}/{RETRIES})"
            )
            time.sleep(RETRY_WAIT)
    if output is None:
        print(f"Failed to get {IMAGE}:{target}")
        return {}
    return {IMAGE: json.loads(output)}


def get_image_digest(image: str, tag: str) -> str:
    """Get image digest using skopeo."""
    result = subprocess.run(
        ["skopeo", "inspect", f"docker://{image}:{tag}"],
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(result.stdout)["Digest"]


def get_sbom(image: str, digest: str) -> dict:
    """Fetch SBOM using ORAS."""
    full_ref = f"{image}@{digest}"

    result = subprocess.run(
        ["oras", "discover", "--format", "json", full_ref],
        capture_output=True,
        text=True,
        check=True,
    )
    discovered = json.loads(result.stdout)

    sbom_digest = None
    for referrer in discovered.get("referrers", []):
        if "spdx+json" in referrer.get("artifactType", ""):
            sbom_digest = referrer["digest"]
            break

    if sbom_digest is None:
        raise RuntimeError(f"No SBOM referrer found for {full_ref}")

    sbom_ref = f"{image}@{sbom_digest}"

    with tempfile.TemporaryDirectory() as tmpdir:
        subprocess.run(
            ["oras", "pull", sbom_ref],
            capture_output=True,
            check=True,
            cwd=tmpdir,
        )

        for fname in os.listdir(tmpdir):
            fpath = os.path.join(tmpdir, fname)
            if fname.endswith(".zst"):
                result = subprocess.run(
                    ["zstd", "-d", fpath, "--stdout"],
                    capture_output=True,
                    check=True,
                )
                return json.loads(result.stdout)
            elif fname.endswith(".json"):
                with open(fpath) as f:
                    return json.load(f)

    raise RuntimeError(f"No SBOM file found after pulling {sbom_ref}")


def parse_sbom_packages(sbom: dict) -> dict[str, str]:
    """Parse RPM packages from a Syft-format SBOM."""
    packages = {}
    for artifact in sbom.get("artifacts", []):
        if artifact.get("type") != "rpm":
            continue
        name = artifact.get("name")
        version = artifact.get("version")
        if name and version:
            if name not in packages or (":" in version and ":" not in packages[name]):
                packages[name] = version

    if not packages:
        print("  Warning: SBOM parsed but no RPM packages found. Check SBOM format/generator.")

    return packages


def get_tags(target: str, manifests: dict[str, Any]):
    tags = set()

    # Select random manifest to get reference tags from
    first = next(iter(manifests.values()))
    for tag in first["RepoTags"]:
        # Tags ending with .0 should not exist
        if tag.endswith(".0"):
            continue
        if target != "stable":
            if re.match(OTHER_START_PATTERN(target), tag):
                tags.add(tag)
        else:
            if re.match(STABLE_START_PATTERN, tag):
                tags.add(tag)

    # Remove tags not present in all images
    for manifest in manifests.values():
        for tag in list(tags):
            if tag not in manifest["RepoTags"]:
                tags.remove(tag)

    tags = list(sorted(tags))
    if len(tags) < 2:
        raise RuntimeError(f"Not enough tags found for target '{target}' (found {len(tags)}), need at least 2.")
    return tags[-2], tags[-1]


def get_packages(tag: str):
    packages = {}
    print(f"Getting packages for {IMAGE}:{tag} via SBOM")
    try:
        digest = get_image_digest(IMAGE, tag)
        sbom = get_sbom(IMAGE, digest)
        packages[IMAGE] = parse_sbom_packages(sbom)
        print(f"  Found {len(packages[IMAGE])} packages")
    except Exception as e:
        print(f"  Failed to get packages for {IMAGE}:{tag}: {e}")
        raise
    return packages


def get_package_groups(prev_tag: str, curr_tag: str):
    print(f"\nFetching current packages for {curr_tag}...")
    npkg = get_packages(curr_tag)
    print(f"\nFetching previous packages for {prev_tag}...")
    ppkg = get_packages(prev_tag)

    current = next(iter(npkg.values()))
    previous = next(iter(ppkg.values()))
    common = sorted(set(current) | set(previous))

    return common, {}, npkg, ppkg


def get_versions(packages: dict[str, dict[str, str]]):
    versions = {}
    for img, img_pkgs in packages.items():
        for pkg, v in img_pkgs.items():
            v = re.sub(EPOCH_PATTERN, "", v)
            versions[pkg] = re.sub(FEDORA_PATTERN, "", v)
    return versions


def calculate_changes(pkgs: list[str], prev: dict[str, str], curr: dict[str, str]):
    added = []
    changed = []
    removed = []

    blacklist_ver = set([curr.get(v, None) for v in BLACKLIST_VERSIONS])

    for pkg in pkgs:
        # Clearup changelog by removing mentioned packages
        if pkg in BLACKLIST_VERSIONS:
            continue
        if pkg in curr and curr.get(pkg, None) in blacklist_ver:
            continue
        if pkg in prev and prev.get(pkg, None) in blacklist_ver:
            continue

        if pkg not in prev:
            added.append(pkg)
        elif pkg not in curr:
            removed.append(pkg)
        elif prev[pkg] != curr[pkg]:
            changed.append(pkg)

        blacklist_ver.add(curr.get(pkg, None))
        blacklist_ver.add(prev.get(pkg, None))

    out = ""
    for pkg in added:
        out += PATTERN_ADD.format(name=pkg, version=curr[pkg])
    for pkg in changed:
        out += PATTERN_CHANGE.format(name=pkg, prev=prev[pkg], new=curr[pkg])
    for pkg in removed:
        out += PATTERN_REMOVE.format(name=pkg, version=prev[pkg])
    return out


def get_commits(prev_manifests, manifests, workdir: str):
    if not workdir:
        return ""

    try:
        start = next(iter(prev_manifests.values()))["Labels"][
            "org.opencontainers.image.revision"
        ]
        finish = next(iter(manifests.values()))["Labels"][
            "org.opencontainers.image.revision"
        ]

        commits = subprocess.run(
            [
                "git",
                "-C",
                workdir,
                "log",
                "--pretty=format:%H|%h|%an|%s",
                f"{start}..{finish}",
            ],
            check=True,
            stdout=subprocess.PIPE,
        ).stdout.decode("utf-8")

        out = ""
        for commit in commits.split("\n"):
            if not commit:
                continue
            parts = commit.split("|")
            if len(parts) < 4:
                continue
            commit_hash, short, author, subject = parts

            if subject.lower().startswith("merge"):
                continue

            out += (
                COMMIT_FORMAT.replace("{short}", short)
                .replace("{subject}", subject)
                .replace("{hash}", commit_hash)
                .replace("{author}", author)
            )

        if out:
            return COMMITS_FORMAT.format(commits=out)
        return ""
    except Exception as e:
        print(f"Failed to get commits:\n{e}")
        return ""


def generate_changelog(
    handwritten: str | None,
    target: str,
    pretty: str | None,
    workdir: str,
    prev_tag: str,
    curr_tag: str,
    prev_manifests,
    manifests,
):
    common, others, curr_packages, prev_packages = get_package_groups(prev_tag, curr_tag)
    versions = get_versions(curr_packages)
    prev_versions = get_versions(prev_packages)

    prev, curr = prev_tag, curr_tag

    if not pretty:
        # Generate pretty version since we dont have it
        try:
            finish: str = next(iter(manifests.values()))["Labels"][
                "org.opencontainers.image.revision"
            ]
        except Exception as e:
            print(f"Failed to get finish hash:\n{e}")
            finish = ""

        # Remove .0 from curr
        curr_pretty = re.sub(r"\.\d{1,2}$", "", curr)
        # Remove target- from curr
        curr_pretty = re.sub(rf"^[a-z]+-", "", curr_pretty)
        pretty = target.capitalize() + " (F" + curr_pretty
        if finish and target != "stable":
            pretty += ", #" + finish[:7]
        pretty += ")"

    title = CHANGELOG_TITLE.format_map(defaultdict(str, tag=curr, pretty=pretty))

    changelog = CHANGELOG_FORMAT

    changelog = (
        changelog.replace(
            "{handwritten}", handwritten if handwritten else HANDWRITTEN_PLACEHOLDER
        )
        .replace("{target}", target)
        .replace("{prev}", prev)
        .replace("{curr}", curr)
    )

    for pkg, v in versions.items():
        if pkg not in prev_versions or prev_versions[pkg] == v:
            changelog = changelog.replace(
                "{pkgrel:" + (PKG_ALIAS.get(pkg, None) or pkg) + "}",
                PATTERN_PKGREL.format(version=v),
            )
        else:
            changelog = changelog.replace(
                "{pkgrel:" + (PKG_ALIAS.get(pkg, None) or pkg) + "}",
                PATTERN_PKGREL_CHANGED.format(prev=prev_versions[pkg], new=v),
            )

    changes = ""
    changes += get_commits(prev_manifests, manifests, workdir)
    common = calculate_changes(common, prev_versions, versions)
    if common:
        changes += COMMON_PAT.format(changes=common)

    changelog = changelog.replace("{changes}", changes)

    return title, changelog


def main():
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("target", help="Target tag")
    parser.add_argument("output", help="Output environment file")
    parser.add_argument("changelog", help="Output changelog file")
    parser.add_argument("--pretty", help="Subject for the changelog")
    parser.add_argument("--workdir", help="Git directory for commits")
    parser.add_argument("--handwritten", help="Handwritten changelog")
    args = parser.parse_args()

    # Remove refs/tags, refs/heads, refs/remotes e.g.
    # Tags cannot include / anyway.
    target = args.target.split("/")[-1]

    if target == "main":
        target = "stable"

    manifests = get_manifests(target)
    prev, curr = get_tags(target, manifests)
    print(f"Previous tag: {prev}")
    print(f" Current tag: {curr}")

    prev_manifests = get_manifests(prev)
    title, changelog = generate_changelog(
        args.handwritten,
        target,
        args.pretty,
        args.workdir,
        prev,
        curr,
        prev_manifests,
        manifests,
    )

    print(f"Changelog:\n# {title}\n{changelog}")
    print(f'\nOutput:\nTITLE="{title}"\nTAG={curr}')

    with open(args.changelog, "w") as f:
        f.write(changelog)

    with open(args.output, "w") as f:
        f.write(f'TITLE="{title}"\nTAG={curr}\n')


if __name__ == "__main__":
    main()

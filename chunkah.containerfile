ARG SOURCE_IMAGE="${SOURCE_IMAGE:-localhost/mimos:build}"
FROM ${SOURCE_IMAGE} AS src

FROM quay.io/coreos/chunkah AS chunkah
RUN --mount=from=src,src=/,target=/chunkah,ro \
    --mount=type=bind,target=/run/src,rw \
    CHUNKAH_CONFIG_STR=$(chunkah inspect /chunkah) \
    chunkah build \
        --prune /sysroot/ \
        --max-layers 128 \
        --label ostree.commit- \
        --label ostree.final-diffid- \
        > /run/src/out.ociarchive

FROM oci-archive:out.ociarchive

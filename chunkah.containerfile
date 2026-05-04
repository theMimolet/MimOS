ARG SOURCE_IMAGE="${SOURCE_IMAGE:-localhost/mimos:build}"
FROM ${SOURCE_IMAGE} AS src

FROM quay.io/coreos/chunkah AS chunkah
ARG CHUNKAH_CONFIG_STR
RUN --mount=from=src,src=/,target=/chunkah,ro \
    --mount=type=bind,target=/run/src,rw \
    chunkah build \
        --prune /sysroot/ \
        --max-layers 128 \
        --label ostree.commit- \
        --label ostree.final-diffid- \
        > /run/src/out.ociarchive

FROM oci-archive:out.ociarchive

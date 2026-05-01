FROM scratch AS ctx

COPY system /system
COPY build /build

FROM ghcr.io/ublue-os/bazzite-nvidia-open:stable

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    /ctx/build.sh

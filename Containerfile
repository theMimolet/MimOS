FROM ghcr.io/ublue-os/bazzite-nvidia-open:stable

COPY system /
COPY build /build

RUN --mount=type=tmpfs,dst=/tmp \
  --mount=type=cache,dst=/var/cache \
  --mount=type=cache,dst=/var/log \
  /build/build.sh

FROM ghcr.io/ublue-os/bazzite-nvidia-open:stable

ARG IMAGE_NAME="${IMAGE_NAME:-mimos}"
ARG IMAGE_VENDOR="${IMAGE_VENDOR:-themimolet}"
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-latest}"
ARG VERSION_TAG="${VERSION_TAG}"
ARG VERSION_PRETTY="${VERSION_PRETTY}"
ARG BASE_IMAGE_NAME="bazzite-nvidia-open"

COPY system /
COPY build /build

RUN --mount=type=tmpfs,dst=/tmp \
  --mount=type=cache,dst=/var/cache \
  --mount=type=cache,dst=/var/log \
  IMAGE_NAME=${IMAGE_NAME} \
  IMAGE_VENDOR=${IMAGE_VENDOR} \
  IMAGE_BRANCH=${IMAGE_BRANCH} \
  BASE_IMAGE_NAME=${BASE_IMAGE_NAME} \
  VERSION_TAG=${VERSION_TAG} \
  VERSION_PRETTY=${VERSION_PRETTY} \
  bash /build/build.sh

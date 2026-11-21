# Your own immich-optimizer image.
#
# It starts from the official image and adds what you need: packages, tools,
# and your tasks file. Every optional part below is commented out; remove the
# leading "# " of the lines of a block to turn it on. Each push to the main
# branch builds this file and publishes the image to your repository's own
# registry (see README.md).

# ---------------------------------------------------------------------------
# The official image this one is built on.
#
#   :latest   the newest release
#   :1.2.3    one release (your image then only changes when you change it)
#   :dev      the development branch
#
# It is Debian 13 with ffmpeg, HandBrakeCLI, ImageMagick, libvips, cjxl/djxl,
# caesiumclt and exiftool. Its ffmpeg already has the hardware encoders for
# NVIDIA (h264_nvenc, hevc_nvenc, av1_nvenc) and for VAAPI (h264_vaapi,
# hevc_vaapi, av1_vaapi), and the open-source VAAPI driver for AMD. So for
# AMD and for NVIDIA you need no extra package: only the device in your
# compose file (README.md) and a task that uses it (config/tasks.yaml). Intel
# needs a driver: see below.
# ---------------------------------------------------------------------------
ARG BASE_IMAGE=ghcr.io/miguelangel-nubla/immich-optimizer:latest

# ---------------------------------------------------------------------------
# Your own build of the optimizer program, from a fork of the main repository.
# Switch this block on together with the COPY line marked "own build" further
# down. Set the repository and the branch.
# ---------------------------------------------------------------------------
# FROM golang:1.26 AS optimizer
# RUN git clone --depth 1 --branch main https://github.com/YOUR-USER/immich-optimizer /src && \
#     cd /src && CGO_ENABLED=0 go build -o /immich-optimizer ./cmd/optimizer

FROM ${BASE_IMAGE}

# Packages are installed as root; the image goes back to its own user below.
USER root

# ---------------------------------------------------------------------------
# Extra packages from Debian. Add the names you need to the list. Find them
# at https://packages.debian.org (the image is Debian 13, "trixie").
#
#   libavif-bin   avifenc and avifdec, for the AVIF example in tasks.yaml
#   webp          cwebp and dwebp
#
# Keep to Debian's own packages where you can. Other people's custom images
# broke on libraries built for another Debian release, and on tools compiled
# for one processor model that crashed on another.
# ---------------------------------------------------------------------------
# RUN apt-get update && \
#     DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
#         libavif-bin \
#         webp \
#     && apt-get clean && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Intel graphics, Broadwell (5th generation) and newer, through VAAPI.
#
# The driver is in Debian's "non-free" section, which has to be switched on
# first. It exists for amd64 only: remove linux/arm64 from PLATFORMS in
# .github/workflows/build.yml.
#
# Older Intel graphics (before Broadwell) use another driver, which is in
# Debian's main section: add i965-va-driver to the list of extra packages
# above instead.
#
# (Quick Sync as such, the "qsv" encoders, is not in Debian's ffmpeg. The
# same hardware is used through VAAPI.)
# ---------------------------------------------------------------------------
# RUN sed -i 's/^Components: main$/Components: main contrib non-free non-free-firmware/' \
#         /etc/apt/sources.list.d/debian.sources && \
#     apt-get update && \
#     DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
#         intel-media-va-driver-non-free \
#     && apt-get clean && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# NVIDIA.
#
# Nothing to install: the driver comes from the host, through the NVIDIA
# Container Toolkit. These two lines only tell it what to hand to the
# container (you can set them in your compose file instead).
# ---------------------------------------------------------------------------
# ENV NVIDIA_VISIBLE_DEVICES=all
# ENV NVIDIA_DRIVER_CAPABILITIES=compute,video,utility

# ---------------------------------------------------------------------------
# A tool that is not in Debian: download a release and put it on the PATH.
# TARGETARCH is "amd64" or "arm64", whichever the image is being built for.
# ---------------------------------------------------------------------------
# ARG TARGETARCH
# RUN curl -fsSL -o /usr/local/bin/mytool \
#         "https://example.com/releases/v1.0.0/mytool-linux-${TARGETARCH}" && \
#     chmod +x /usr/local/bin/mytool

# ---------------------------------------------------------------------------
# "own build": the program built in the first block replaces the image's.
# ---------------------------------------------------------------------------
# COPY --from=optimizer /immich-optimizer /usr/local/bin/immich-optimizer

# ---------------------------------------------------------------------------
# The tasks the image starts with: everything in config/ replaces the official
# image's default tasks file, so that a tool or driver added above is used
# without further setup. Scripts next to tasks.yaml can be called from a task
# as ./script.sh. A folder mounted over /etc/immich-optimizer/config at run
# time still replaces all of it; for tasks alone you need no custom image.
# ---------------------------------------------------------------------------
COPY --chown=appuser:appuser config/ /etc/immich-optimizer/config/

# Back to the unprivileged user the official image runs as (uid 1001).
USER appuser

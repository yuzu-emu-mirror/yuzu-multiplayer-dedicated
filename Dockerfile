# syntax=docker/dockerfile:1.3
FROM debian:bullseye AS build
ENV DEBIAN_FRONTEND=noninteractive
ARG USE_CCACHE
RUN apt-get update && apt-get -y full-upgrade && \
    apt-get install -y build-essential wget git ccache cmake ninja-build libssl-dev pkg-config libarchive-tools

COPY . /root/build-files

RUN --mount=type=cache,id=ccache,target=/root/.ccache \
    git clone --depth 1000 -j4 --recursive https://github.com/yuzu-emu/yuzu-mainline.git /root/yuzu-mainline && \
    cd /root/yuzu-mainline && /root/build-files/.ci/build.sh

FROM gcr.io/distroless/cc-debian11 AS final
LABEL maintainer="yuzuemu"
# Create app directory
WORKDIR /usr/src/app
COPY --from=build /root/yuzu-mainline/build/bin/yuzu-room /usr/src/app

ENTRYPOINT [ "/usr/src/app/yuzu-room" ]

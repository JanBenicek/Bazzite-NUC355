# Custom Bazzite KDE image for ASUS NUC 14 Essential / Intel Core 3 N355
# Based on the official Universal Blue image-template model.

FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

# Bazzite desktop image = KDE Plasma. The stable tag tracks upstream Bazzite stable.
FROM ghcr.io/ublue-os/bazzite:stable

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

RUN bootc container lint

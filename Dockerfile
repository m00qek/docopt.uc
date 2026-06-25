FROM openwrt/rootfs:x86-64-25.12.3

RUN wget -qO /etc/apk/keys/packages.ucode.dev.pem \
        https://m00qek.github.io/packages.ucode.dev/25.12/feed.pub.pem && \
    echo "https://m00qek.github.io/packages.ucode.dev/25.12" \
        >> /etc/apk/repositories.d/customfeeds.list && \
    apk update && \
    apk add ucode-utest

WORKDIR /app

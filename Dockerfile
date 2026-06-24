FROM openwrt/rootfs:x86-64-25.12.3

RUN wget -qO /tmp/utest.apk \
        https://m00qek.github.io/packages.ucode.dev/25.12/x86_64/ucode-utest-1.3.0-r1.apk && \
    apk add --allow-untrusted /tmp/utest.apk && \
    rm /tmp/utest.apk

WORKDIR /app

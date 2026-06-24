FROM openwrt/rootfs:x86-64-openwrt-24.10

RUN mkdir -p /var/lock && \
    wget -qO /tmp/utest.ipk \
        https://m00qek.github.io/packages.ucode.dev/24.10/ucode-utest_1.3.0-r1_all.ipk && \
    opkg install /tmp/utest.ipk && \
    rm /tmp/utest.ipk

WORKDIR /app

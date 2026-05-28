FROM openwrt/rootfs:x86-64-openwrt-24.10

RUN mkdir -p /var/lock && \
    wget -qO /tmp/utest.ipk \
        https://github.com/m00qek/utest/releases/download/v0.9.0/ucode-utest_0.9.0.e11934bb-r1_all.ipk && \
    opkg install /tmp/utest.ipk && \
    rm /tmp/utest.ipk

WORKDIR /app

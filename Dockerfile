FROM openwrt/rootfs:x86-64-openwrt-24.10

RUN mkdir -p /var/lock /etc/opkg/keys && \
    printf 'untrusted comment: public key 69415029ba91237e\nRWRpQVApupEjfkw39TbIuq1GmjfU23KO6OmGOz6DBxSU/VbyhkE8tQY2\n' \
        > /etc/opkg/keys/69415029ba91237e && \
    echo "src/gz ucode.dev https://m00qek.github.io/packages.ucode.dev/24.10" \
        > /etc/opkg/customfeeds.conf && \
    : > /etc/opkg/distfeeds.conf && \
    opkg update && \
    opkg install ucode-utest

WORKDIR /app

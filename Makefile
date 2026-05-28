IMAGE       := ucode-docopt-test:latest
SDK_VERSION ?= 24.10.6
SDK_ARCH    ?= x86-64
GIT_COMMIT  ?= $(shell git rev-parse --short HEAD)

PKG_NAME    := $(shell grep -oP 'PKG_NAME:=\K.*' openwrt/ucode-docopt/Makefile)
PKG_VERSION := $(shell grep -oP 'PKG_VERSION:=\K.*' openwrt/ucode-docopt/Makefile)~$(GIT_COMMIT)

.PHONY: image test shell package

image:
	docker build -t $(IMAGE) .

test: image
	docker run --rm \
		-v $(CURDIR):/app \
		-w /app \
		$(IMAGE) \
		utest -l /app/src test/

shell: image
	docker run --rm -it \
		-v $(CURDIR):/app \
		-w /app \
		$(IMAGE) \
		sh

package:
	mkdir -p bin
	docker run --rm \
		-v $(CURDIR)/src:/builder/package/$(PKG_NAME)/src \
		-v $(CURDIR)/openwrt/ucode-docopt/Makefile:/builder/package/$(PKG_NAME)/Makefile \
		-v $(CURDIR)/openwrt/ucode-docopt/test.sh:/builder/package/$(PKG_NAME)/test.sh \
		-v $(CURDIR)/bin:/builder/bin \
		openwrt/sdk:$(SDK_ARCH)-$(SDK_VERSION) \
		sh -c " \
			sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=$(PKG_VERSION)/' package/$(PKG_NAME)/Makefile && \
			./scripts/feeds update base && \
			./scripts/feeds install ucode && \
			make defconfig && \
			make package/$(PKG_NAME)/compile V=s \
		"

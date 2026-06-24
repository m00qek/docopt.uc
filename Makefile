IMAGE       := ucode-docopt-test:latest
SDK_VERSION ?= 25.12.3
SDK_ARCH    ?= x86-64
GIT_COMMIT  ?= $(shell git rev-parse --short HEAD)

PKG_NAME         := $(shell grep -oP 'PKG_NAME:=\K.*' openwrt/ucode-docopt/Makefile)
PKG_VERSION_BASE := $(shell grep -oP 'PKG_VERSION:=\K.*' openwrt/ucode-docopt/Makefile)
PKG_VERSION      := $(if $(GIT_COMMIT),$(PKG_VERSION_BASE)~$(GIT_COMMIT),$(PKG_VERSION_BASE))

.PHONY: image test shell package lint

image:
	docker build -t $(IMAGE) .

lint:
	ucode-lint

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
	chmod 777 bin
	sed 's/PKG_VERSION:=.*/PKG_VERSION:=$(PKG_VERSION)/' \
		openwrt/ucode-docopt/Makefile > /tmp/$(PKG_NAME)-Makefile
	docker run --rm \
		-v $(CURDIR)/src:/builder/package/$(PKG_NAME)/src:ro \
		-v /tmp/$(PKG_NAME)-Makefile:/builder/package/$(PKG_NAME)/Makefile:ro \
		-v $(CURDIR)/openwrt/ucode-docopt/test.sh:/builder/package/$(PKG_NAME)/test.sh:ro \
		-v $(CURDIR)/bin:/builder/bin \
		openwrt/sdk:$(SDK_ARCH)-$(SDK_VERSION) \
		sh -c " \
			./scripts/feeds update base && \
			./scripts/feeds install ucode && \
			make defconfig && \
			make package/$(PKG_NAME)/compile V=s \
		"

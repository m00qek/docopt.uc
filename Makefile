IMAGE       := ucode-docopt-test:latest
SDK_VERSION ?= 25.12.3
SDK_ARCH    ?= x86-64
GIT_COMMIT  ?= $(shell git rev-parse --short HEAD)

PKG_NAME         := $(shell sed -n 's/^PKG_NAME:=//p' openwrt/ucode-docopt/Makefile)
PKG_VERSION_BASE := $(shell sed -n 's/^PKG_VERSION:=//p' openwrt/ucode-docopt/Makefile)
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

# The SDK image builds as its own user, whose uid is not ours: bin/ (git-
# ignored, a build's output only) must be writable to it. The versioned
# package Makefile is written there too, not to a shared /tmp path.
package:
	mkdir -p bin
	chmod a+rwx bin
	sed 's/PKG_VERSION:=.*/PKG_VERSION:=$(PKG_VERSION)/' \
		openwrt/ucode-docopt/Makefile > bin/.$(PKG_NAME)-Makefile
	docker run --rm \
		-v $(CURDIR)/src:/builder/package/$(PKG_NAME)/src:ro \
		-v $(CURDIR)/bin/.$(PKG_NAME)-Makefile:/builder/package/$(PKG_NAME)/Makefile:ro \
		-v $(CURDIR)/openwrt/ucode-docopt/test.sh:/builder/package/$(PKG_NAME)/test.sh:ro \
		-v $(CURDIR)/bin:/builder/bin \
		openwrt/sdk:$(SDK_ARCH)-$(SDK_VERSION) \
		sh -c " \
			./scripts/feeds update base && \
			./scripts/feeds install ucode && \
			make defconfig && \
			make package/$(PKG_NAME)/compile V=s \
		"

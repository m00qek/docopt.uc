IMAGE       := ucode-docopt-test:latest
SDK_VERSION ?= 24.10.6
SDK_ARCH    ?= x86-64
UTEST_SRC   ?= $(abspath $(CURDIR)/../utest/src)
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
		-v $(UTEST_SRC)/utest.sh:/usr/bin/utest:ro \
		-v $(UTEST_SRC)/utest.uc:/usr/share/ucode/utest.uc:ro \
		-v $(UTEST_SRC)/utest:/usr/share/ucode/utest:ro \
		-w /app \
		$(IMAGE) \
		utest -l /app/src test/

shell: image
	docker run --rm -it \
		-v $(CURDIR):/app \
		-v $(UTEST_SRC)/utest.sh:/usr/bin/utest:ro \
		-v $(UTEST_SRC)/utest.uc:/usr/share/ucode/utest.uc:ro \
		-v $(UTEST_SRC)/utest:/usr/share/ucode/utest:ro \
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

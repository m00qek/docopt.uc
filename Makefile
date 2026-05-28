IMAGE := ucode-docopt-test:latest

.PHONY: image test shell

image:
	docker build -t $(IMAGE) -f Dockerfile.test .

test: image
	docker run --rm \
		-v $(CURDIR):/app \
		-w /app \
		$(IMAGE) \
		utest -l /app/src tests/

shell: image
	docker run --rm -it \
		-v $(CURDIR):/app \
		-w /app \
		$(IMAGE) \
		sh

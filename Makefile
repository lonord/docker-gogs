APP_NAME = "gogs"
REGISTRY = "dkr.lonord.name"

.PHONY: all docker-build clean

all: docker-build

docker-build:
	docker buildx build --platform=linux/amd64,linux/arm64 -t $(REGISTRY)/$(APP_NAME) . --push

clean:
	find . -name "*.DS_Store" -type f -delete

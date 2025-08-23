.PHONY: dev app net down

GIT_AUTHOR=$(shell git log -1 --pretty=format:%an)
GIT_SHA=$(shell git rev-parse --short=12 HEAD)

dev: net
	GIT_AUTHOR=$(GIT_AUTHOR) GIT_SHA=$(GIT_SHA) docker compose -f docker-compose.yml up -d --build

app: net
	GIT_AUTHOR=$(GIT_AUTHOR) GIT_SHA=$(GIT_SHA) docker compose -f docker-compose.yml -f docker-compose-o11y.yml up -d --build

net:
	@docker network inspect dokploy-network >/dev/null 2>&1 || docker network create dokploy-network

down:
	docker compose -f docker-compose.yml -f docker-compose-o11y.yml down
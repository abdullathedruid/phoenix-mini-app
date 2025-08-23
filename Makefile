.PHONY: dev app net down

dev: net
	docker compose -f docker-compose.yml up -d

app: net
	docker compose -f docker-compose.yml -f docker-compose-o11y.yml up -d

net:
	@docker network inspect dokploy-network >/dev/null 2>&1 || docker network create dokploy-network

down:
	docker compose -f docker-compose.yml -f docker-compose-o11y.yml down
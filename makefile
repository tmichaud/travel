SHELL := /bin/bash

# ==============================================================================
# Building containers

all: travel-api travel-ui

travel-api:
	docker build \
		-f z/compose/dockerfile.travel-api \
		-t travel-api-amd64:1.0 \
		--build-arg PACKAGE_NAME=travel-api \
		--build-arg VCS_REF=`git rev-parse HEAD` \
		--build-arg BUILD_DATE=`date -u +”%Y-%m-%dT%H:%M:%SZ”` \
		.

travel-ui:
	docker build \
		-f z/compose/dockerfile.travel-ui \
		-t travel-ui-amd64:1.0 \
		--build-arg PACKAGE_NAME=travel-ui \
		--build-arg VCS_REF=`git rev-parse HEAD` \
		--build-arg BUILD_DATE=`date -u +”%Y-%m-%dT%H:%M:%SZ”` \
		.

# ==============================================================================
# Running from within docker compose

run: up seed browse

up:
	docker-compose -f z/compose/compose.yaml -f z/compose/compose-config.yaml up --detach --remove-orphans

down:
	docker-compose -f z/compose/compose.yaml down --remove-orphans

browse:
	python -m webbrowser "http://localhost"

logs:
	docker-compose -f z/compose/compose.yaml logs -f

# ==============================================================================
# Running from within k8s/dev

kind-up:
	kind create cluster --name dgraph-travel-cluster --config z/k8s/dev/kind-config.yaml

kind-down:
	kind delete cluster --name dgraph-travel-cluster

kind-load:
	kind load docker-image travel-ui-amd64:1.0 --name dgraph-travel-cluster
	kind load docker-image travel-api-amd64:1.0 --name dgraph-travel-cluster

kind-services:
	kustomize build z/k8s/dev | kubectl apply -f -

kind-schema:
	go run app/travel-admin/main.go --custom-functions-upload-feed-url=http://localhost:3000/v1/feed/upload schema

kind-seed: kind-schema
	go run app/travel-admin/main.go seed 

kind-logs:
	kubectl logs -lapp=travel --all-containers=true -f

kind-status:
	kubectl get nodes
	kubectl get pods
	kubectl get services travel

kind-delete:
	kustomize build . | kubectl delete -f -

# ==============================================================================
# Running from within the local with Slash

slash-run: slash-up seed slash-browse

slash-up:
	docker-compose -f z/compose/compose-slash.yaml -f z/compose/compose-slash-config.yaml up --detach --remove-orphans

slash-down:
	docker-compose -f z/compose/compose-slash.yaml down --remove-orphans

slash-browse:
	python -m webbrowser "http://localhost"

slash-logs:
	docker-compose -f z/compose/compose-slash.yaml logs -f

# ==============================================================================
# Running Local

local-run: local-up seed browse

local-up:
	go run app/travel-api/main.go &> api.log &
	cd app/travel-ui; \
	go run main.go &> ../../ui.log &

API := $(shell lsof -i tcp:4000 | cut -c9-13 | grep "[0-9]")
UI := $(shell lsof -i tcp:4080 | cut -c9-13 | grep "[0-9]")

ps:
	lsof -i tcp:4000; \
	lsof -i tcp:4080

local-down:
	kill -15 $(API); \
	kill -15 $(UI); \
	rm *.log

api-logs:
	tail -F api.log

ui-logs:
	tail -F ui.log

# ==============================================================================
# Administration

schema:
	go run app/travel-admin/main.go schema

seed: schema
	go run app/travel-admin/main.go seed

# Running tests within the local computer

test:
	go test ./... -count=1
	staticcheck ./...

# Modules support

deps-reset:
	git checkout -- go.mod
	go mod tidy
	go mod vendor

tidy:
	go mod tidy
	go mod vendor

deps-upgrade:
	go get -u -t -d -v ./...
	go mod tidy
	go mod vendor

deps-cleancache:
	go clean -modcache

# ==============================================================================
# Docker support

FILES := $(shell docker ps -aq)

down-local:
	docker stop $(FILES)
	docker rm $(FILES)

clean:
	docker system prune -f

logs-local:
	docker logs -f $(FILES)

# ==============================================================================
# Git support

install-hooks:
	cp -r .githooks/pre-commit .git/hooks/pre-commit

remove-hooks:
	rm .git/hooks/pre-commit
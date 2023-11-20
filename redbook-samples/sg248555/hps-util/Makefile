.PHONY: build app test m maintenance coverage clean

WORKSPACE ?= $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

# load environment (optional)
include $(wildcard .env*)
export $(shell sed 's/=.*//' .env*)

test: maintenance
	make clean
	mkdir -p build
	go test ./... -covermode=count -coverpkg=./... -coverprofile build/cover.out

m maintenance:
	go mod tidy
	go fmt ./...
	go vet ./...
	gosec ./...

coverage: test
	go tool cover -html=build/cover.out -o build/cover.html

build app:
	env CGO_ENABLED=0 GOOS=linux go build -v ./...

clean:
	-rm build/cover.out
	-rm build/cover.html
#!make

all: build

build: Dockerfile
	docker build -t sps:latest .

push: build
	docker tag icr.io/samplepaymentsystem/sps sps:latest
	docker push icr.io/samplepaymentsystem/sps

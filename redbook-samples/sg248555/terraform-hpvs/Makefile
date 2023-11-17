#!make

SHELL:=/bin/bash
.ONESHELL:

# load environment (optional)
include $(wildcard .env*)
export $(shell sed 's/=.*//' .env*)

export TF_VAR_enc_file_name=build/hpcr-rev13-encrypt.crt

all: apply

.terraform.lock.hcl:
	@echo Terraform init ...
	terraform init -upgrade

${TF_VAR_enc_file_name}: .terraform.lock.hcl sample/nginx/sample.test.crt sample/nginx/sample.test.key
	mkdir -p build
	curl https://cloud.ibm.com/media/docs/downloads/hyper-protect-container-runtime/ibm-hyper-protect-container-runtime-1-0-s390x-13-encrypt.crt > $${TF_VAR_enc_file_name}

apply ip: ${TF_VAR_enc_file_name}
	@echo "Deploying" ...
	terraform apply -auto-approve

ssh: ip
	ssh $$(cat ip) -p 22

term terminal:
	gnome-terminal -- ssh root@$$(cat ip) -p 22

destroy:
	terraform destroy -auto-approve

cert sample/nginx/sample.test.crt sample/nginx/sample.test.key:
	test -f ip || echo 0.0.0.0 >ip
	openssl req -x509 -newkey rsa:4096 -sha256 -days 30 \
		-nodes -keyout sample/nginx/sample.test.key -out sample/nginx/sample.test.crt -subj "/CN=sample.test" \
		-addext "subjectAltName=DNS:sample.test,DNS:*.sample.test,IP:$$(cat ip)"

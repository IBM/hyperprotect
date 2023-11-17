#!make

SHELL:=/bin/bash
.ONESHELL:

# load environment (optional)
include $(wildcard .env*)
export $(shell sed 's/=.*//' .env*)

export CLOUDTKEFILES=$(shell pwd)/build/tke/

all: apply

.terraform.lock.hcl:
	@echo Terraform init ...
	terraform init -upgrade

${CLOUDTKEFILES}/SIGKEYS ${CLOUDTKEFILES}/1.sigkey: .terraform.lock.hcl
	mkdir -p ${CLOUDTKEFILES}
# create keys for user admin with password 1234qwer
	ibmcloud tke sigkey-add

apply ip: ${CLOUDTKEFILES}/SIGKEYS ${CLOUDTKEFILES}/1.sigkey
	@echo "Deploying" ...
	terraform apply #-auto-approve

destroy:
	terraform destroy -auto-approve

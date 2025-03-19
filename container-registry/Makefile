# Makefile for Container Registry Deployment

.PHONY: help deploy deploy-registry deploy-vllm install-prerequisites lint check clean

ANSIBLE_PATH := ansible
INVENTORY := $(ANSIBLE_PATH)/inventory/hosts.yml

help:
	@echo "Container Registry Deployment"
	@echo ""
	@echo "Usage:"
	@echo "  make deploy               Deploy the complete solution"
	@echo "  make deploy-registry      Deploy only the registry"
	@echo "  make deploy-vllm          Deploy only the vLLM service"
	@echo "  make install-prerequisites Install common and docker on all servers"
	@echo "  make lint                 Check ansible playbooks for errors"
	@echo "  make check                Run ansible in check mode (dry run)"
	@echo "  make clean                Clean up temporary files"

deploy:
	cd $(ANSIBLE_PATH) && ansible-playbook -i $(INVENTORY) site.yml

deploy-registry:
	cd $(ANSIBLE_PATH) && ansible-playbook -i $(INVENTORY) site.yml --tags registry

deploy-vllm:
	cd $(ANSIBLE_PATH) && ansible-playbook -i $(INVENTORY) site.yml --tags vllm

install-prerequisites:
	cd $(ANSIBLE_PATH) && ansible-playbook -i $(INVENTORY) site.yml --tags setup

lint:
	cd $(ANSIBLE_PATH) && ansible-lint site.yml

check:
	cd $(ANSIBLE_PATH) && ansible-playbook -i $(INVENTORY) site.yml --check

clean:
	find . -name "*.retry" -type f -delete
	find . -name "*.pyc" -type f -delete
	find . -name "__pycache__" -type d -exec rm -rf {} +

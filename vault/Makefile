SHELL := /bin/bash
-include .env
export VAULT_ADDR   ?= https://127.0.0.1:8200
export VAULT_CACERT ?= $(CURDIR)/tls/ca.crt
export MAC_IP

.PHONY: unseal-vars setup tls up down logs init unseal status configure post-configure snapshot schedule-snapshots check

setup:          ## first-time setup in one command
	scripts/setup.sh

tls:            ## create the CA and server certificate
	scripts/gen-tls.sh

up:             ## start Vault
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f vault

init:           ## one-off; KEYCHAIN=1 to store unseal keys in the keychain
	scripts/init.sh

unseal:         ## after every restart of the Mac or Docker
	scripts/unseal.sh

status:
	docker exec vault vault status

configure:      ## apply mounts, policies and auth as code (needs VAULT_TOKEN)
	cd terraform && terraform init -input=false && terraform apply

post-configure: ## one-off; admin user, snapshot token, revoke root
	scripts/post-configure.sh

snapshot:
	scripts/snapshot.sh

schedule-snapshots: ## daily snapshot at 02:17 via launchd
	sed "s|__REPO__|$(abspath $(CURDIR)/..)|" launchd/local.homelab.vault-snapshot.plist > ~/Library/LaunchAgents/local.homelab.vault-snapshot.plist
	launchctl bootstrap gui/$$(id -u) ~/Library/LaunchAgents/local.homelab.vault-snapshot.plist

check:
	shellcheck -x scripts/*.sh
	cd terraform && terraform fmt -check && terraform init -backend=false -input=false >/dev/null && terraform validate
	docker compose config -q

unseal-vars:    ## encrypted unseal keys for the AAP job "homelab 05 - unseal Vault"
	bash scripts/make-unseal-vars.sh

SHELL := /bin/bash

ARGOCD_CHART_DIR := bootstrap/argocd
ARGOCD_NAMESPACE := argocd
ARGOCD_RELEASE := argocd-bootstrap
ARGOCD_REPOSITORY_NAME := argo
ARGOCD_REPOSITORY_URL := https://argoproj.github.io/argo-helm
AWS_ACCOUNT_ID := 730335441285
AWS_PROFILE ?= default
AWS_REGION := ap-southeast-1
ECR_REGISTRY := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
ECR_SECRET_NAME := ecr-registry
GITOPS_ROOT := gitops/clusters/local
APP_NAMESPACE := online-boutique
KUBE_CONTEXT ?= $(shell kubectl config current-context 2>/dev/null)

.PHONY: argocd-repository argocd-dependencies validate-gitops check-kind-context bootstrap-gitops refresh-ecr-secret

argocd-repository:
	helm repo add $(ARGOCD_REPOSITORY_NAME) $(ARGOCD_REPOSITORY_URL) --force-update

argocd-dependencies: argocd-repository
	helm dependency build $(ARGOCD_CHART_DIR) --skip-refresh

validate-gitops: argocd-dependencies
	helm lint $(ARGOCD_CHART_DIR)
	helm template $(ARGOCD_RELEASE) $(ARGOCD_CHART_DIR) \
		--namespace $(ARGOCD_NAMESPACE) >/dev/null
	helm lint gitops/apps/chart
	helm template online-boutique gitops/apps/chart \
		--namespace $(APP_NAMESPACE) \
		-f gitops/apps/chart/values.yaml \
		-f gitops/apps/chart/values-images.yaml >/dev/null



check-kind-context:
	@test -n "$(KUBE_CONTEXT)" || { echo "Kubernetes context is not set"; exit 1; }
	@case "$(KUBE_CONTEXT)" in \
		kind-*) ;; \
		*) echo "Refusing to bootstrap non-Kind context: $(KUBE_CONTEXT)"; exit 1 ;; \
	esac
	@kubectl --context "$(KUBE_CONTEXT)" cluster-info >/dev/null

bootstrap-gitops: check-kind-context validate-gitops
	helm upgrade --install $(ARGOCD_RELEASE) $(ARGOCD_CHART_DIR) \
		--kube-context "$(KUBE_CONTEXT)" \
		--namespace $(ARGOCD_NAMESPACE) \
		--create-namespace \
		--set rootApplication.enabled=false \
		--rollback-on-failure \
		--wait \
		--timeout 10m
	helm upgrade $(ARGOCD_RELEASE) $(ARGOCD_CHART_DIR) \
		--kube-context "$(KUBE_CONTEXT)" \
		--namespace $(ARGOCD_NAMESPACE) \
		--set rootApplication.enabled=true \
		--rollback-on-failure \
		--wait \
		--timeout 10m

refresh-ecr-secret: check-kind-context
	@command -v aws >/dev/null || { echo "aws CLI is required"; exit 1; }
	@kubectl --context "$(KUBE_CONTEXT)" get namespace "$(APP_NAMESPACE)" >/dev/null || { \
		echo "Namespace $(APP_NAMESPACE) does not exist; commit and sync GitOps manifests first"; \
		exit 1; \
	}
	@set -euo pipefail; \
		umask 077; \
		task_secret_dir="$$(mktemp -d)"; \
		trap 'rm -rf "$$task_secret_dir"' EXIT; \
		ecr_password="$$(aws ecr get-login-password --region "$(AWS_REGION)" --profile "$(AWS_PROFILE)")"; \
		ecr_auth="$$(printf 'AWS:%s' "$$ecr_password" | base64 | tr -d '\n')"; \
		printf '{"auths":{"%s":{"auth":"%s"}}}\n' "$(ECR_REGISTRY)" "$$ecr_auth" > "$$task_secret_dir/config.json"; \
		kubectl create secret generic "$(ECR_SECRET_NAME)" \
			--namespace "$(APP_NAMESPACE)" \
			--from-file=.dockerconfigjson="$$task_secret_dir/config.json" \
			--type=kubernetes.io/dockerconfigjson \
			--dry-run=client \
			--output=yaml | \
		kubectl --context "$(KUBE_CONTEXT)" apply --filename=-

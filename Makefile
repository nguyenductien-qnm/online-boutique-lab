SHELL := /bin/bash

ARGOCD_CHART_DIR := bootstrap/argocd
ARGOCD_NAMESPACE := argocd
ARGOCD_RELEASE := argocd-bootstrap
GITOPS_ROOT := gitops/clusters/local
KUBE_CONTEXT ?= $(shell kubectl config current-context 2>/dev/null)

.PHONY: argocd-dependencies validate-gitops check-kind-context bootstrap-gitops

argocd-dependencies:
	helm dependency build $(ARGOCD_CHART_DIR)

validate-gitops: argocd-dependencies
	helm lint $(ARGOCD_CHART_DIR)
	helm template $(ARGOCD_RELEASE) $(ARGOCD_CHART_DIR) \
		--namespace $(ARGOCD_NAMESPACE) >/dev/null
	kubectl kustomize $(GITOPS_ROOT) >/dev/null

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
		--atomic \
		--wait \
		--timeout 10m

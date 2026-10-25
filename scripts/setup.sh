#!/usr/bin/env bash
set -euo pipefail
for b in docker kind kubectl; do command -v $b >/dev/null || { echo "missing: $b"; exit 1; }; done
kind get clusters | grep -qx argocd-lab || kind create cluster --name argocd-lab
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
echo "Waiting for Argo CD..."
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
echo; echo "Admin password:"; kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
echo "Next: make ui   (https://localhost:8080, user: admin)"

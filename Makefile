.PHONY: cluster ui password bootstrap status dev staging prod clean
cluster:
	bash scripts/setup.sh
ui:
	kubectl -n argocd port-forward svc/argocd-server 8080:443
password:
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
bootstrap:
	kubectl apply -f argocd/project.yaml && kubectl apply -f argocd/root.yaml
status:
	kubectl -n argocd get applications; kubectl get pods -A | grep lab-
dev:
	kubectl -n lab-dev port-forward svc/web 8081:80
staging:
	kubectl -n lab-staging port-forward svc/web 8082:80
prod:
	kubectl -n lab-prod port-forward svc/web 8083:80
clean:
	kind delete cluster --name argocd-lab

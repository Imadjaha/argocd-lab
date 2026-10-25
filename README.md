# Argo CD lab

A small but complete GitOps playground. Argo CD watches **this repo** and keeps three environments (dev, staging, prod) in sync on a local kind cluster.

```
deploy/base/            the app: web (nginx) + api (node), config via ConfigMaps, two hooks
deploy/overlays/{dev,staging,prod}/   Kustomize overlays: replicas, env name, version
argocd/project.yaml     AppProject: what this team may deploy, from where, to where
argocd/root.yaml        app-of-apps: Argo CD manages its own Applications from Git
argocd/apps/            one Application per environment, each with a different sync policy
argocd/extras/          ApplicationSet (exercise 8)
```

No images to build: code and HTML live in ConfigMaps, so every change you make is a Git change.

## Prerequisites
Docker, [kind](https://kind.sigs.k8s.io), kubectl, git, perl, and an empty GitHub repo (public is easiest).

## Quick start
```bash
# 1. Point the manifests at YOUR repo and push
git init -b main && git add -A && git commit -m "initial"
bash scripts/set-repo.sh https://github.com/<you>/argocd-lab.git
git add -A && git commit -m "set repo url"
git remote add origin https://github.com/<you>/argocd-lab.git && git push -u origin main

# 2. Cluster + Argo CD (prints the admin password)
make cluster

# 3. UI in a second terminal: https://localhost:8080  (admin / password above)
make ui

# 4. Hand Argo CD the project and the root app
make bootstrap
```
Within a minute the UI shows `root`, then `lab-dev`, `lab-staging`, `lab-prod`. Prod will say **OutOfSync** because it waits for you. Click Sync.

View the app: `make dev` then http://localhost:8081 (staging 8082, prod 8083).

## Exercises
Do them in order. After each Git push, Argo CD polls every ~3 minutes. Click **Refresh** in the UI to skip the wait.

1. **Git is the source of truth.** Change `APP_VERSION=v1` to `v2` in `deploy/overlays/dev/kustomization.yaml`, push, refresh. Dev rolls out and the page shows v2. Staging and prod still show v1.
2. **Self-heal.** `kubectl -n lab-dev scale deploy web --replicas=5`. Argo CD reverts it to 1 within seconds (`selfHeal: true`).
3. **No self-heal.** Do the same in `lab-staging`. It shows OutOfSync but stays at 5 until you sync. Compare `argocd/apps/lab-dev.yaml` with `lab-staging.yaml`.
4. **Prune.** Delete the `api` Service block from `deploy/base/app.yaml`, push. The page loses its API data and Argo CD deletes the Service in dev and staging. Undo with `git revert`.
5. **Manual prod and promotion.** Set `APP_VERSION=v2` in staging, push, check it. Do the same in prod and press Sync. Use the **Diff** view before syncing.
6. **Rollback.** In the prod app open **History and rollback** and roll back one revision. Rollback is disabled for apps with auto-sync, because Git would simply win again.
7. **Hooks.** Sync prod and watch the `presync-check` and `postsync-notify` Jobs appear and disappear in the resource tree.
8. **ApplicationSet.** `kubectl apply -f argocd/extras/applicationset.yaml`. Two more apps appear in `set-dev` and `set-staging`. Add `- {env: prod}` to the list and watch a third arrive.
9. **Break it on purpose.** Put a typo in `deploy/base/app.yaml` (`image: nginx:does-not-exist`). The app goes **Degraded** while the old pods keep serving. Fix it in Git.
10. **Delete cascade.** Delete `argocd/apps/lab-staging.yaml` in Git. The root app prunes the Application, and its finalizer removes the workloads.

## Concepts you just used
| Concept | Where |
|---|---|
| Application | `argocd/apps/*.yaml` |
| AppProject (guardrails) | `argocd/project.yaml` |
| Sync policy: automated, prune, selfHeal | `argocd/apps/` |
| Health vs Sync status | UI badges: Healthy/Degraded, Synced/OutOfSync |
| App of apps | `argocd/root.yaml` |
| ApplicationSet | `argocd/extras/` |
| Hooks | `deploy/base/hooks.yaml` |
| Kustomize overlays and generators | `deploy/` |

## Optional CLI
```bash
brew install argocd        # or see argo-cd.readthedocs.io
argocd login localhost:8080 --insecure --username admin
argocd app list
argocd app diff lab-prod
argocd app sync lab-prod
argocd app history lab-prod
```

## Troubleshooting
- **ComparisonError / repo not accessible**: repo is private or the URL is wrong. Make it public, or add credentials under Settings > Repositories.
- **Project errors**: the repo URL in `argocd/project.yaml` must match the Applications exactly.
- **Nothing changes after push**: click Refresh, and confirm you pushed to `main`.
- **Reset everything**: `make clean`, then start again at `make cluster`.

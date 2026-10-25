# Argo CD lab

This repository is a small GitOps playground. It deploys the same web/API application into three Kubernetes environments: `dev`, `staging`, and `prod`.

This guide assumes you have never used Argo CD. It explains what Argo CD does, how the files fit together, how to start the lab, how to test it, and what each exercise demonstrates.

## 1. What are Kubernetes, GitOps, and Argo CD?

### Kubernetes

Kubernetes runs containers and keeps them available. You describe the desired state in YAML:

- a Deployment says how many application pods should run;
- a Service gives pods a stable network name and port;
- a ConfigMap stores non-secret configuration or small files.

This lab uses [kind](https://kind.sigs.k8s.io), which runs a local Kubernetes cluster inside Docker. Nothing is deployed to a cloud provider.

### GitOps

GitOps means that Git is the source of truth for the cluster. The normal workflow is:

1. edit a YAML file in this repository;
2. commit and push the change;
3. let an automation tool apply the desired state to Kubernetes.

### Argo CD

Argo CD is the automation tool in this lab. It continuously compares:

- **desired state**: the Kubernetes configuration stored in Git;
- **live state**: what is currently running in the cluster.

When the two differ, Argo CD reports the application as `OutOfSync`. Depending on the application policy, it either syncs automatically or waits for you to click **Sync**.

Argo CD also reports health. `Healthy` means resources appear to be running correctly. `Degraded` or `Missing` means something needs attention.

## 2. How this lab works

```text
You edit files
      |
      v
GitHub repository  <--- Argo CD watches this repository
      |
      v
Argo CD Applications
      |
      v
Local kind Kubernetes cluster
      |
      v
Web page + Node.js API in dev, staging, and prod
```

There are three separate Kubernetes namespaces:

| Environment | Namespace     | Web replicas | API replicas | Sync behavior                   |
| ----------- | ------------- | -----------: | -----------: | ------------------------------- |
| Dev         | `lab-dev`     |            1 |            1 | Automatic sync and self-healing |
| Staging     | `lab-staging` |            2 |            2 | Automatic sync, no self-healing |
| Prod        | `lab-prod`    |            3 |            3 | Manual sync                     |

These policies are intentional. Dev is fast and automatically corrected. Staging accepts manual experiments but reports drift. Prod requires human approval before changes are applied.

## 3. What is deployed?

The application has two components:

- **Web**: an Nginx container serving the HTML page;
- **API**: a Node.js container returning the environment, version, pod name, and current time.

The Nginx web service forwards `/api/` requests to the internal `api` Kubernetes Service. The browser therefore shows data from an API pod.

There are no application images to build. The HTML and Node.js source are placed into ConfigMaps by Kustomize, which keeps this lab small.

## 4. Repository structure

```text
deploy/base/                         Shared application manifests
deploy/base/app.yaml                 Web and API Deployments and Services
deploy/base/hooks.yaml               Argo CD pre-sync and post-sync Jobs
deploy/base/kustomization.yaml       Shared ConfigMaps and resources
deploy/base/web/                     Nginx HTML and configuration
deploy/base/api/                     Node.js API source
deploy/overlays/dev/                 Dev namespace, replicas, and version
deploy/overlays/staging/             Staging namespace, replicas, and version
deploy/overlays/prod/                Prod namespace, replicas, and version
argocd/project.yaml                  Argo CD permissions and destinations
argocd/root.yaml                     Root app that manages child Applications
argocd/apps/                         One Argo CD Application per environment
argocd/extras/                       ApplicationSet exercise
scripts/setup.sh                     Creates kind and installs Argo CD
scripts/set-repo.sh                  Replaces the Git repository URL
Makefile                             Short commands for lab operations
```

## 5. Prerequisites

Install:

- Docker, with the Docker daemon running
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- Git
- Perl
- An empty GitHub repository

A public GitHub repository is easiest. The repository URL is configuration, not a credential. Never commit GitHub tokens, cloud credentials, kubeconfig files, `.env` files, or private keys.

Check the tools:

```bash
docker --version
kind version
kubectl version --client
git --version
perl --version
```

## 6. First-time setup

Run commands from the project directory:

```bash
cd /<your-path>/argocd-lab
```

### Step 1: Create and push your Git repository

Create an empty repository on GitHub, for example:

```text
https://github.com/<your-user>/argocd-lab.git
```

Initialize the local repository and make the initial commit:

```bash
git init -b main
git add -A
git commit -m "initial"
```

Replace the placeholder repository URL in the Argo CD manifests:

```bash
bash scripts/set-repo.sh https://github.com/<your-user>/argocd-lab.git
```

Commit and push:

```bash
git add -A
git commit -m "set repository URL"
git remote add origin https://github.com/<your-user>/argocd-lab.git
git push -u origin main
```

Argo CD must be able to read this repository. If it is private, configure repository credentials in Argo CD instead of putting credentials in Git.

### Step 2: Create Kubernetes and install Argo CD

```bash
make cluster
```

This runs `scripts/setup.sh`. It creates a kind cluster named `argocd-lab`, creates the `argocd` namespace, installs Argo CD, waits for the server, and prints the generated admin password.

The password is stored in the local Kubernetes Secret `argocd-initial-admin-secret`. It is not stored in this Git repository.

Check the cluster:

```bash
kubectl get nodes
kubectl -n argocd get pods
```

Wait until the Argo CD pods are ready.

### Step 3: Open the Argo CD web interface

Open a second terminal and run:

```bash
make ui
```

Keep this command running. It forwards local port `8080` to the Argo CD server.

Open:

```text
https://localhost:8080
```

A browser certificate warning is expected because this is a local development endpoint. Log in with:

```text
Username: admin
Password: the password printed by make cluster
```

Retrieve the password again with:

```bash
make password
```

### Step 4: Bootstrap Argo CD

Open a third terminal and run:

```bash
make bootstrap
```

This applies:

- `argocd/project.yaml`: repository and namespace guardrails;
- `argocd/root.yaml`: the root Application.

The root Application reads `argocd/apps/` from Git. Those files define `lab-dev`, `lab-staging`, and `lab-prod`.

Check them:

```bash
kubectl -n argocd get applications
make status
```

Dev and staging should sync automatically. Prod normally shows `OutOfSync` and `Missing` because it is configured for manual sync. Open `lab-prod` in the Argo CD UI, click **Sync**, and click **Synchronize**.

## 7. View and test the application

Each port-forward command must stay running in its own terminal.

### Dev

```bash
make dev
```

Open `http://localhost:8081`.

### Staging

```bash
make staging
```

Open `http://localhost:8082`.

### Prod

First sync `lab-prod`, then run:

```bash
make prod
```

Open `http://localhost:8083`.

Test the API directly:

```bash
curl http://localhost:8081/api/
curl http://localhost:8082/api/
curl http://localhost:8083/api/
```

A response looks like this:

```json
{ "version": "v1", "env": "prod", "pod": "api-...", "time": "..." }
```

The pod name and time change. The environment and version show which overlay is deployed.

Inspect resources:

```bash
kubectl -n lab-dev get all
kubectl -n lab-staging get all
kubectl -n lab-prod get all
```

Inspect logs when a pod is not ready:

```bash
kubectl -n lab-prod get pods
kubectl -n lab-prod logs deployment/web
kubectl -n lab-prod logs deployment/api
```

## 8. Understand the Argo CD UI

An Argo CD Application connects a Git path to a Kubernetes destination. For example, `lab-prod` points to:

```text
Git repository: https://github.com/<your-user>/argocd-lab.git
Git path:       deploy/overlays/prod
Namespace:      lab-prod
```

Important UI terms:

- **Synced**: live Kubernetes resources match Git.
- **OutOfSync**: live resources differ from Git, or resources are missing.
- **Healthy**: resources appear to be running correctly.
- **Degraded**: one or more resources are unhealthy.
- **Missing**: a resource expected by Git does not exist in Kubernetes.
- **Refresh**: ask Argo CD to check Git immediately.
- **Sync**: apply the Git version to Kubernetes.
- **Diff**: show exactly what would change before syncing.
- **History and rollback**: show previous sync revisions and allow rollback where policy permits.

`Refresh` only checks for differences. `Sync` applies changes.

## 9. GitOps exercises

Do these in order. After pushing a commit, Argo CD may take a few minutes to poll Git. Click **Refresh** in the UI to check immediately.

### Exercise 1: Git is the source of truth

Change the dev version from `v1` to `v2`:

```bash
perl -pi -e 's/APP_VERSION=v1/APP_VERSION=v2/' deploy/overlays/dev/kustomization.yaml
git add deploy/overlays/dev/kustomization.yaml
git commit -m "update dev to v2"
git push
```

Refresh `lab-dev`, then run:

```bash
curl http://localhost:8081/api/
```

Dev should show `v2`. Staging and prod should still show `v1` because they use different overlay files.

### Exercise 2: Dev self-heals

```bash
kubectl -n lab-dev scale deployment/web --replicas=5
kubectl -n lab-dev get deployment web
```

Dev has `selfHeal: true`, so Argo CD detects the manual change and returns the Deployment to one replica.

### Exercise 3: Staging reports drift but does not self-heal

```bash
kubectl -n lab-staging scale deployment/web --replicas=5
kubectl -n lab-staging get deployment web
```

Staging becomes `OutOfSync`, but remains at five replicas until you sync it. Compare [argocd/apps/lab-dev.yaml](argocd/apps/lab-dev.yaml) with [argocd/apps/lab-staging.yaml](argocd/apps/lab-staging.yaml).

### Exercise 4: Pruning deleted resources

Delete the API Service block from `deploy/base/app.yaml`, commit, and push. Dev and staging have pruning enabled, so Argo CD removes the API Service after syncing. The web page can no longer reach the API.

Restore the change safely with:

```bash
git revert <commit-that-deleted-the-service>
git push
```

### Exercise 5: Manual production promotion

Change the staging overlay to `APP_VERSION=v2`, commit, and push. After checking staging, change the production overlay to `APP_VERSION=v2`, commit, and push.

Open the `lab-prod` **Diff** view, review the change, and click **Sync**. Production does not deploy the Git change until a person approves it.

### Exercise 6: Rollback

In the prod Application, open **History and rollback** and roll back one revision. Rollback is useful for a manual-sync application such as prod. It is not a lasting fix for an automatically synced application because Git will become the desired state again.

### Exercise 7: Sync hooks

Sync prod and watch the resource tree. The pre-sync and post-sync Jobs from `deploy/base/hooks.yaml` run during the sync and then disappear according to their hook-delete policy.

### Exercise 8: ApplicationSet

Apply the optional ApplicationSet:

```bash
kubectl apply -f argocd/extras/applicationset.yaml
```

It generates Applications for `set-dev` and `set-staging`. Add `- {env: prod}` to the list in the ApplicationSet, commit and push the file, and observe the third generated Application.

### Exercise 9: Create a failed deployment

Temporarily change the web image in `deploy/base/app.yaml` to:

```yaml
image: nginx:does-not-exist
```

Commit and push. The new web pods cannot start, so Argo CD reports the application as `Degraded`. Existing pods may continue serving while Kubernetes attempts the failed rollout.

Fix the image name in Git, commit, and push again.

### Exercise 10: Delete an Application

Delete `argocd/apps/lab-staging.yaml` in Git and push. The root Application notices the deletion, prunes the child Application, and the child Application finalizer removes its Kubernetes workloads.

## 10. What each Argo CD manifest does

### AppProject

[argocd/project.yaml](argocd/project.yaml) defines the `lab` project. It limits which repository and destination namespaces the lab Applications may use. This is a guardrail, not a password store.

### Root Application

[argocd/root.yaml](argocd/root.yaml) is an app-of-apps. It points Argo CD at `argocd/apps/`, where the child Application definitions live. The root Application lets Git manage the set of environments too.

### Environment Applications

| File               | Git path                  | Namespace     | Policy                      |
| ------------------ | ------------------------- | ------------- | --------------------------- |
| `lab-dev.yaml`     | `deploy/overlays/dev`     | `lab-dev`     | Auto-sync, prune, self-heal |
| `lab-staging.yaml` | `deploy/overlays/staging` | `lab-staging` | Auto-sync and prune         |
| `lab-prod.yaml`    | `deploy/overlays/prod`    | `lab-prod`    | Manual sync                 |

### Kustomize

The base contains shared resources. Each overlay adds its namespace, replica counts, environment name, and version. This avoids copying the entire application definition for every environment.

## 11. Optional Argo CD CLI

The web UI is enough for this lab. The optional CLI is useful for scripting:

```bash
argocd login localhost:8080 --insecure --username admin
argocd app list
argocd app get lab-prod
argocd app diff lab-prod
argocd app sync lab-prod
argocd app history lab-prod
```

Install the CLI using the [Argo CD CLI documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd/).

## 12. Troubleshooting

### Argo CD says the repository is not accessible

Check the repository references:

```bash
grep -R "repoURL\|sourceRepos" argocd
```

For a private repository, add repository credentials in Argo CD. Never put a GitHub token in a YAML file committed to this repository.

### Applications do not appear

```bash
kubectl -n argocd get application root
kubectl -n argocd describe application root
```

Confirm that Git contains `argocd/apps/` on the `main` branch.

### Nothing changes after a Git push

1. Confirm the push succeeded with `git status` and `git log -1`.
2. Confirm the commit is on `main`.
3. Click **Refresh** in Argo CD.
4. Open **Diff** to see what Argo CD believes changed.
5. Check events with `kubectl -n argocd describe application <name>`.

### Prod is `OutOfSync` or `Missing`

That is expected until prod is manually synchronized:

```bash
argocd app sync lab-prod
```

Alternatively, click **Sync** in the UI.

### The local web URL does not open

Make sure the matching port-forward is running:

```bash
make dev       # http://localhost:8081
make staging   # http://localhost:8082
make prod      # http://localhost:8083
```

Each command must remain running in its terminal. Confirm the Service exists:

```bash
kubectl -n lab-prod get service web
```

### A pod is not ready

```bash
kubectl -n lab-prod get pods
kubectl -n lab-prod describe pod <pod-name>
kubectl -n lab-prod logs <pod-name>
```

### Reset the lab

This deletes the entire local kind cluster and all applications in it:

```bash
make clean
```

Afterward, start again with `make cluster`.

## 13. Makefile command reference

| Command          | What it does                                 |
| ---------------- | -------------------------------------------- |
| `make cluster`   | Creates kind and installs Argo CD            |
| `make ui`        | Forwards Argo CD to `https://localhost:8080` |
| `make password`  | Prints the local Argo CD admin password      |
| `make bootstrap` | Applies the project and root Application     |
| `make status`    | Shows Argo CD Applications and lab pods      |
| `make dev`       | Forwards dev web to `localhost:8081`         |
| `make staging`   | Forwards staging web to `localhost:8082`     |
| `make prod`      | Forwards prod web to `localhost:8083`        |
| `make clean`     | Deletes the kind cluster                     |

#!/usr/bin/env bash
# Usage: scripts/set-repo.sh https://github.com/<you>/argocd-lab.git
set -euo pipefail
[ $# -eq 1 ] || { echo "usage: $0 <git-repo-url>"; exit 1; }
grep -rl "REPO_URL_PLACEHOLDER" argocd | xargs perl -pi -e "s#REPO_URL_PLACEHOLDER#$1#g"
echo "Repo URL set. Now: git add -A && git commit -m 'set repo' && git push origin main"

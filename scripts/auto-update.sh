#!/bin/sh
# Keeps every checked-out repo of the ecosystem in sync with its own GitHub remote so the
# already-running, hot-reloading containers pick up new commits without any manual step.
# Fast-forward only: never overwrites uncommitted local changes or diverged history.
#
# Every repo in this ecosystem now has a CI pipeline (unit tests + coverage >= 80% gate for the
# Python services with real code; Docker build / config validation for the stubs, infra repo, and
# the top-level resume-ia repo, Constitution Principle III) that only advances its `deployed`
# branch after a merge to `main` passes. This script always tracks `deployed`, never `main`,
# so the local environment can never pick up a commit that hasn't actually passed CI.
set -u

INTERVAL=15
REPOS="/workspace /workspace/resume-server /workspace/apps/resume-app /workspace/services/resume-bff /workspace/services/resume-guard-rails /workspace/services/resume-llm-engine /workspace/services/resume-injections /workspace/services/resume-orchestrator /workspace/services/resume-embeddings"

git config --global --add safe.directory '*'

echo "auto-updater: watching $(echo "$REPOS" | wc -w) CI-gated repos (deployed branch) every ${INTERVAL}s (fast-forward only)"

update_gated() {
  repo="$1"
  branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)
  [ -n "$branch" ] && [ "$branch" != "HEAD" ] || return 0

  if ! git -C "$repo" fetch origin deployed --quiet 2>/dev/null; then
    echo "auto-updater: $repo has no 'deployed' branch yet (CI hasn't passed on main), waiting"
    return 0
  fi

  local_rev=$(git -C "$repo" rev-parse HEAD 2>/dev/null)
  remote_rev=$(git -C "$repo" rev-parse FETCH_HEAD 2>/dev/null)

  if [ -n "$remote_rev" ] && [ "$local_rev" != "$remote_rev" ]; then
    if git -C "$repo" merge --ff-only FETCH_HEAD --quiet 2>/dev/null; then
      echo "auto-updater: $repo updated to $(git -C "$repo" rev-parse --short HEAD) (CI-gated: deployed)"
    else
      echo "auto-updater: $repo has local/diverged changes, skipped (no force)"
    fi
  fi
}

while true; do
  for repo in $REPOS; do
    [ -d "$repo/.git" ] && update_gated "$repo"
  done
  sleep "$INTERVAL"
done

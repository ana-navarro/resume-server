#!/bin/sh
# Keeps every checked-out repo of the ecosystem in sync with its own GitHub remote so the
# already-running, hot-reloading containers pick up new commits without any manual step.
# Fast-forward only: never overwrites uncommitted local changes or diverged history.
#
# GATED_REPOS have a CI pipeline (unit tests + coverage >= 80% gate for the Python services with
# real code; Docker build / config validation for the stubs and infra repo, Constitution
# Principle III) that only advances their `deployed` branch after a merge to `main` passes. This
# script tracks `deployed`, not `main`, for those repos, so the local environment never picks up a
# commit that hasn't actually passed CI. Every repo that actually runs in docker-compose is
# gated; DIRECT_REPOS is just the outer `resume-ia` repo (task tracking, not part of the compose
# stack), which has no pipeline and keeps the old behavior of tracking its branch directly.
set -u

INTERVAL=15
GATED_REPOS="/workspace/resume-server /workspace/apps/resume-app /workspace/services/resume-bff /workspace/services/resume-guard-rails /workspace/services/resume-llm-engine /workspace/services/resume-injections /workspace/services/resume-orchestrator /workspace/services/resume-embeddings"
DIRECT_REPOS="/workspace"

git config --global --add safe.directory '*'

echo "auto-updater: watching $(echo "$GATED_REPOS" | wc -w) CI-gated repos (deployed branch) and $(echo "$DIRECT_REPOS" | wc -w) direct repos every ${INTERVAL}s (fast-forward only)"

update_direct() {
  repo="$1"
  branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)
  [ -n "$branch" ] && [ "$branch" != "HEAD" ] || return 0

  git -C "$repo" fetch origin "$branch" --quiet 2>/dev/null

  local_rev=$(git -C "$repo" rev-parse HEAD 2>/dev/null)
  remote_rev=$(git -C "$repo" rev-parse "origin/$branch" 2>/dev/null)

  if [ -n "$remote_rev" ] && [ "$local_rev" != "$remote_rev" ]; then
    if git -C "$repo" pull --ff-only origin "$branch" --quiet 2>/dev/null; then
      echo "auto-updater: $repo updated to $(git -C "$repo" rev-parse --short HEAD)"
    else
      echo "auto-updater: $repo has local/diverged changes, skipped (no force)"
    fi
  fi
}

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
  for repo in $GATED_REPOS; do
    [ -d "$repo/.git" ] && update_gated "$repo"
  done
  for repo in $DIRECT_REPOS; do
    [ -d "$repo/.git" ] && update_direct "$repo"
  done
  sleep "$INTERVAL"
done

#!/bin/sh
# Keeps every checked-out repo of the ecosystem in sync with its own GitHub remote so the
# already-running, hot-reloading containers pick up new commits without any manual step.
# Fast-forward only: never overwrites uncommitted local changes or diverged history.
set -u

INTERVAL=15
REPOS="/workspace /workspace/resume-server /workspace/apps/resume-app /workspace/services/resume-bff /workspace/services/resume-guard-rails /workspace/services/resume-llm-engine /workspace/services/resume-injections /workspace/services/resume-orchestrator /workspace/services/resume-embeddings"

git config --global --add safe.directory '*'

echo "auto-updater: watching $(echo $REPOS | wc -w) repos every ${INTERVAL}s (fast-forward only)"

while true; do
  for repo in $REPOS; do
    if [ -d "$repo/.git" ]; then
      branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)
      if [ -n "$branch" ] && [ "$branch" != "HEAD" ]; then
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
      fi
    fi
  done
  sleep "$INTERVAL"
done

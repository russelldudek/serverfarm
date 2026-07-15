#!/usr/bin/env bash
set -u

status_dir=/tmp/workflow-status
rm -rf "$status_dir"
git fetch origin workflow-status:workflow-status
if ! git worktree add "$status_dir" workflow-status; then
  exit 90
fi

status_write() {
  local state="$1"
  local detail_file="${2:-}"
  {
    printf 'state=%s\n' "$state"
    printf 'source_sha=%s\n' "${GITHUB_SHA:-unknown}"
    printf 'updated_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if [[ -n "$detail_file" && -f "$detail_file" ]]; then
      printf '\n--- detail ---\n'
      tail -c 60000 "$detail_file"
    fi
  } > "$status_dir/publisher-status.txt"
  (
    cd "$status_dir"
    git config user.name 'github-actions[bot]'
    git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
    git add publisher-status.txt
    git diff --cached --quiet || git commit -m "Record publisher status: $state"
    git push origin workflow-status
  )
}

status_write started
bash -x .payload/materialize.sh > /tmp/serverfarm-publisher.log 2>&1
rc=$?
if [[ "$rc" -eq 0 ]]; then
  status_write succeeded /tmp/serverfarm-publisher.log
  exit 0
fi
status_write failed /tmp/serverfarm-publisher.log
exit "$rc"

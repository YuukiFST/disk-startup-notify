set -euo pipefail

APP_ID="disk-startup-notify"
MOUNT="${DISK_CLEANUP_MOUNT:-/}"
DISK_CLEANUP_ROOT="${DISK_CLEANUP_ROOT:-disk-cleanup-root}"
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/disk-cleanup.lock"
PROGRESS_ID=87421
STEP_TIMEOUT_MS=5000
SUMMARY_TIMEOUT_MS=15000

exec 8>"$LOCK_FILE"
if ! flock -n 8; then
  notify-send -a "$APP_ID" -u low -t 5000 "Cleanup already running" \
    "A disk cleanup is already in progress." 2>/dev/null || true
  exit 0
fi

notify() {
  local title="$1"
  local body="$2"
  local urgency="${3:-normal}"
  local timeout="${4:-$STEP_TIMEOUT_MS}"

  if command -v notify-send >/dev/null 2>&1; then
    notify-send -a "$APP_ID" -u "$urgency" -t "$timeout" "$title" "$body"
  fi
}

notify_progress() {
  local title="$1"
  local body="$2"
  local urgency="${3:-normal}"
  local timeout="${4:-$STEP_TIMEOUT_MS}"

  if command -v notify-send >/dev/null 2>&1; then
    notify-send -a "$APP_ID" -r "$PROGRESS_ID" -u "$urgency" -t "$timeout" \
      "$title" "$body"
  fi
}

human_size() {
  local bytes="$1"

  if command -v numfmt >/dev/null 2>&1; then
    numfmt --to=iec-i --suffix=B "$bytes" 2>/dev/null && return 0
  fi

  if [ "$bytes" -ge 1073741824 ]; then
    awk -v b="$bytes" 'BEGIN { printf "%.1f GB", b / 1073741824 }'
  elif [ "$bytes" -ge 1048576 ]; then
    awk -v b="$bytes" 'BEGIN { printf "%.1f MB", b / 1048576 }'
  elif [ "$bytes" -ge 1024 ]; then
    awk -v b="$bytes" 'BEGIN { printf "%.1f KB", b / 1024 }'
  else
    printf '%s B' "$bytes"
  fi
}

read_disk_stats() {
  df -BG "$MOUNT" | awk 'NR==2 {
    gsub(/G/, "", $2)
    gsub(/G/, "", $3)
    gsub(/G/, "", $4)
    print $2, $3, $4
  }'
}

dir_size_bytes() {
  local target="$1"

  if [ ! -d "$target" ]; then
    echo 0
    return 0
  fi

  local size=0
  size="$({ du -sb "$target" 2>/dev/null || true; } | awk 'END { print $1 + 0 }')"
  echo "$size"
}

count_dir_entries() {
  local target="$1"

  if [ ! -d "$target" ]; then
    echo 0
    return 0
  fi

  find "$target" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' '
}

clean_dir_contents() {
  local target="$1"

  if [ ! -d "$target" ]; then
    return 0
  fi

  find "$target" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
}

clean_user_dir() {
  local label="$1"
  local target="$2"
  local before_bytes
  local after_bytes
  local freed_bytes
  local entry_count

  if [ ! -d "$target" ]; then
    return 0
  fi

  entry_count="$(count_dir_entries "$target")"
  before_bytes="$(dir_size_bytes "$target")"

  if [ "$entry_count" -eq 0 ]; then
    return 0
  fi

  notify_progress "Cleaning: $label" \
    "Removing $entry_count item(s) from:\n$target\n(~$(human_size "$before_bytes"))"

  clean_dir_contents "$target"

  after_bytes="$(dir_size_bytes "$target")"
  freed_bytes=$((before_bytes - after_bytes))

  if [ "$freed_bytes" -gt 0 ]; then
    notify_progress "Done: $label" "Freed $(human_size "$freed_bytes")"
  else
    notify_progress "Done: $label" "Removed $entry_count item(s)"
  fi
}

clean_user_cache_cmd() {
  local label="$1"
  local cmd="$2"
  shift 2
  local before_free
  local after_free
  local freed_gb

  if ! command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi

  before_free="$(df -BG "$MOUNT" | awk 'NR==2 { gsub(/G/, "", $4); print $4 }')"
  notify_progress "Cleaning: $label" "Running: $cmd $*"

  if "$cmd" "$@" 2>/dev/null; then
    after_free="$(df -BG "$MOUNT" | awk 'NR==2 { gsub(/G/, "", $4); print $4 }')"
    freed_gb=$((after_free - before_free))

    if [ "$freed_gb" -gt 0 ]; then
      notify_progress "Done: $label" "Freed ~${freed_gb} GB"
    else
      notify_progress "Done: $label" "Cache cleared"
    fi
  else
    notify_progress "Skipped: $label" "Could not clear cache"
  fi
}

run_root_cleanup() {
  local before_free
  local after_free
  local freed_gb

  before_free="$(df -BG "$MOUNT" | awk 'NR==2 { gsub(/G/, "", $4); print $4 }')"

  notify_progress "Cleaning: system" \
    "Removing unused Nix store paths, optimising store, and vacuuming logs older than 7 days..."

  if sudo -n "$DISK_CLEANUP_ROOT" 2>/dev/null; then
    after_free="$(df -BG "$MOUNT" | awk 'NR==2 { gsub(/G/, "", $4); print $4 }')"
    freed_gb=$((after_free - before_free))

    if [ "$freed_gb" -gt 0 ]; then
      notify_progress "Done: system" "Freed ~${freed_gb} GB (Nix store + logs)"
    else
      notify_progress "Done: system" "System cleanup finished"
    fi
    return 0
  fi

  notify_progress "Skipped: system cleanup" \
    "Could not run system cleanup (sudo denied).\nUser-level files were still cleaned."
  return 1
}

read -r before_total before_used before_free < <(read_disk_stats)

notify_progress "Starting cleanup" \
  "Before: ${before_used} GB used, ${before_free} GB free (of ${before_total} GB)"

clean_user_dir "Temp files (/tmp)" /tmp
clean_user_dir "Temp files (/var/tmp)" /var/tmp
clean_user_dir "Trash" "${HOME}/.local/share/Trash/files"
clean_user_dir "Trash metadata" "${HOME}/.local/share/Trash/info"
clean_user_dir "App caches" "${HOME}/.cache"
clean_user_cache_cmd "npm cache" npm cache clean --force
clean_user_cache_cmd "pip cache" pip cache purge
run_root_cleanup || true

read -r after_total after_used after_free < <(read_disk_stats)
freed_gb=$((before_used - after_used))

summary="Before: ${before_used} GB used | ${before_free} GB free (of ${before_total} GB)
After:  ${after_used} GB used | ${after_free} GB free (of ${after_total} GB)"

if [ "$freed_gb" -gt 0 ]; then
  summary="${summary}

Freed: ${freed_gb} GB"
  notify "Cleanup complete" "$summary" "normal" "$SUMMARY_TIMEOUT_MS"
elif [ "$freed_gb" -lt 0 ]; then
  summary="${summary}

Disk usage increased by $((0 - freed_gb)) GB (other processes may be writing)."
  notify "Cleanup complete" "$summary" "normal" "$SUMMARY_TIMEOUT_MS"
else
  summary="${summary}

No significant disk space change detected."
  notify "Cleanup complete" "$summary" "low" 12000
fi

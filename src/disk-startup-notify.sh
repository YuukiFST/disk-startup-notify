set -euo pipefail

THRESHOLD_GB=@threshold@
MOUNT="@mount@"
DUNST_WAIT_SEC=@dunstWait@
APP_ID="disk-startup-notify"
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/disk-startup-notify.lock"

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  exit 0
fi

sleep "$DUNST_WAIT_SEC"

read_disk_stats() {
  df -BG "$MOUNT" | awk 'NR==2 {
    gsub(/G/, "", $2)
    gsub(/G/, "", $3)
    gsub(/G/, "", $4)
    print $2, $3, $4
  }'
}

read -r total used avail < <(read_disk_stats)

message="Total: ${total} GB | Used: ${used} GB | Free: ${avail} GB"

if [ "$avail" -le "$THRESHOLD_GB" ]; then
  title="Low disk space"
  urgency="critical"
else
  title="Disk usage"
  urgency="normal"
fi

body="${message}

Safe cleanup removes:
• /tmp and /var/tmp
• Trash (~/.local/share/Trash)
• App caches (~/.cache)
• npm and pip caches
• Unused Nix store paths
• System logs older than 7 days

Does NOT touch: ~/.config, ~/Projects, ~/.pi

Choose an option below to clean or dismiss."

notify-send -a "$APP_ID" -u "$urgency" -t 15000 "$title" "$body"

choice=$(
  printf '%s\n' "Dismiss" "Clean now" |
    rofi -dmenu -i -p "$title" -mesg "$body" -select "Dismiss" 2>/dev/null || true
)

case "${choice:-}" in
  "Clean now")
    confirm=$(
      printf '%s\n' "No, keep files" "Yes, clean now" |
        rofi -dmenu -i -p "Confirm cleanup" \
          -mesg "This will remove temp files, caches, trash, and old system data." \
          -select "No, keep files" 2>/dev/null || true
    )

    case "${confirm:-}" in
      "Yes, clean now")
        disk-cleanup || true
        ;;
    esac
    ;;
esac

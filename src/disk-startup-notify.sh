set -euo pipefail

THRESHOLD_GB=@threshold@
MOUNT="@mount@"
DUNST_WAIT_SEC=@dunstWait@
APP_ID="disk-startup-notify"

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
else
  title="Disk usage"
fi

body="${message}

Safe cleanup removes:
• /tmp and /var/tmp
• Trash (~/.local/share/Trash)
• App caches (~/.cache)
• npm and pip caches
• Unused Nix store paths
• System logs older than 7 days

Does NOT touch: ~/.config, ~/Projects, ~/.pi"

choice=$(
  printf '%s\n' "Clean now" "Dismiss" |
    rofi -dmenu -i -p "$title" -mesg "$body" 2>/dev/null || true
)

case "${choice:-}" in
  "Clean now")
    disk-cleanup || true
    read -r total used avail < <(read_disk_stats)
    notify-send -a "$APP_ID" -t 10000 "Disk after cleanup" \
      "Total: ${total} GB | Used: ${used} GB | Free: ${avail} GB"
    ;;
esac

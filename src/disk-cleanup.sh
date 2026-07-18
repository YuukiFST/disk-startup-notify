set -euo pipefail

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -a disk-startup-notify "$1" "$2"
  fi
}

run_root() {
  local desc="$1"
  shift

  if sudo -n "$@" 2>/dev/null; then
    return 0
  fi

  if command -v pkexec >/dev/null 2>&1 && pkexec "$@"; then
    return 0
  fi

  notify "Partial cleanup" "Could not run: $desc (authentication denied)."
  return 1
}

clean_dir_contents() {
  local target="$1"

  if [ ! -d "$target" ]; then
    return 0
  fi

  find "$target" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
}

clean_dir_contents /tmp
clean_dir_contents /var/tmp
clean_dir_contents "${HOME}/.local/share/Trash/files"
clean_dir_contents "${HOME}/.local/share/Trash/info"
clean_dir_contents "${HOME}/.cache"

if command -v npm >/dev/null 2>&1; then
  npm cache clean --force 2>/dev/null || true
fi

if command -v pip >/dev/null 2>&1; then
  pip cache purge 2>/dev/null || true
fi

run_root "nix-collect-garbage" nix-collect-garbage -d || true
run_root "nix-store optimise" nix-store --optimise || true
run_root "journal vacuum" journalctl --vacuum-time=7d || true

notify "Cleanup complete" \
  "Removed temp files, trash, app caches, npm/pip cache, unused Nix store paths, and logs older than 7 days."

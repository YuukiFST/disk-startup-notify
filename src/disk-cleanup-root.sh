#!/usr/bin/env bash
# Root-only cleanup steps. Invoked via passwordless sudo (disk-cleanup-root).
set -euo pipefail

nix-collect-garbage -d
nix-store --optimise
journalctl --vacuum-time=7d

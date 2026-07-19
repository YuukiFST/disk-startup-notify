# disk-startup-notify

Shows disk usage on graphical login and offers optional safe cleanup.

## Features

- Dunst notification on login with current disk usage
- Rofi menu to start cleanup or dismiss
- Per-step progress notifications (what is being cleaned, skipped, or empty)
- Final summary with before/after usage and space freed

## NixOS module

Enable in `configuration.nix`:

```nix
services.disk-startup-notify = {
  enable = true;
  cleanupUser = "your-user";
};
```

Add to i3 startup:

```
exec --no-startup-id disk-startup-notify
```

After changes, rebuild:

```bash
sudo nixos-rebuild switch
```

## Sudo

System cleanup (Nix garbage collection, store optimise, journal vacuum) runs via a single passwordless sudo rule for `disk-cleanup-root`.

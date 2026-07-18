{
  lib,
  pkgs,
  lowSpaceThresholdGb ? 15,
  mountPoint ? "/",
  dunstWaitSeconds ? 3,
}:

let
  inherit (pkgs) writeShellApplication coreutils findutils nix systemd libnotify dunst sudo polkit rofi nodejs python3;

  diskCleanup = writeShellApplication {
    name = "disk-cleanup";
    runtimeInputs = [
      coreutils
      findutils
      nix
      systemd
      libnotify
      dunst
      sudo
      polkit
      nodejs
      python3
    ];
    text = builtins.readFile ./src/disk-cleanup.sh;
  };

  notifyText =
    builtins.replaceStrings
      [
        "@threshold@"
        "@mount@"
        "@dunstWait@"
      ]
      [
        (toString lowSpaceThresholdGb)
        mountPoint
        (toString dunstWaitSeconds)
      ]
      (builtins.readFile ./src/disk-startup-notify.sh);

  diskStartupNotify = writeShellApplication {
    name = "disk-startup-notify";
    runtimeInputs = [
      coreutils
      dunst
      libnotify
      rofi
      diskCleanup
    ];
    text = notifyText;
  };
in
diskStartupNotify

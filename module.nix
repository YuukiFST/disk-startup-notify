{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.disk-startup-notify;

  diskStartupNotifyPkg = pkgs.callPackage ./package.nix {
    lowSpaceThresholdGb = cfg.lowSpaceThresholdGb;
    mountPoint = cfg.mountPoint;
    dunstWaitSeconds = cfg.dunstWaitSeconds;
  };
in
{
  options.services.disk-startup-notify = {
    enable = lib.mkEnableOption "disk usage notification on graphical login";

    lowSpaceThresholdGb = lib.mkOption {
      type = lib.types.int;
      default = 15;
      description = "Offer interactive cleanup when free space is at or below this value (GB).";
    };

    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/";
      description = "Mount point to monitor (root filesystem where NixOS is installed).";
    };

    dunstWaitSeconds = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = "Seconds to wait after session start before showing the notification.";
    };

    cleanupUser = lib.mkOption {
      type = lib.types.str;
      example = "yuuki";
      description = "User allowed to run cleanup commands without a password.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.dunst
      diskStartupNotifyPkg.diskStartupNotify
    ];

    environment.etc."xdg/dunst/dunstrc".source = ./config/dunstrc;

    security.sudo.extraRules = [
      {
        users = [ cfg.cleanupUser ];
        commands = [
          {
            command = "${diskStartupNotifyPkg.diskCleanupRoot}/bin/disk-cleanup-root";
            options = [
              "NOPASSWD"
              "SETENV"
            ];
          }
        ];
      }
    ];
  };
}

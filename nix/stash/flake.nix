{
  description = "stash nix OCI image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      packages.${system}.image =
        pkgs.dockerTools.buildImage {
          name = "stash";
          tag = "0.29.1";

          copyToRoot = [
            pkgs.stash
          ];

          config = {
            Cmd = [
              "${pkgs.slskd}/bin/stash"
              "--config"
              "/etc/stash/config.yml"
              "--host"
              "0.0.0.0"
              "--port"
              "8080"
              "--nobrowser"
            ];
            WorkingDir = "/var/lib/stash";
            User = "1000:1000";
          };

          extraCommands = ''
            mkdir -p config data etc
            echo 'nzbget:x:1000:1000::/data:/sbin/nologin' > etc/passwd
            echo 'nzbget:x:!:1::::::' > etc/shadow
          '';
        };
    };
}


{
  description = "NZBGet distroless-style OCI image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
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
          name = "nzbget";
          tag = "25.4";

          copyToRoot = [
            pkgs.nzbget
            pkgs.python3
            pkgs.unrar
            pkgs.p7zip
          ];

          config = {
            Cmd = [
              "${pkgs.nzbget}/bin/nzbget"
              "-s"
              "-c"
              "/config/nzbget.conf"
            ];
            WorkingDir = "/data";
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


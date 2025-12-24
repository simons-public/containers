{
  description = "Emby Server with ffmpeg NVENC (NVIDIA)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          cudaSupport = true;
        };
      };

      ffmpegNv = pkgs.ffmpeg.override {
        withNvenc = true;
        withCuda = true;
        withNvdec = true;
      };
    in {
      packages.${system}.image =
        pkgs.dockerTools.buildImage {
          name = "emby-nvidia";
          tag = "latest";

          copyToRoot = [
            pkgs.emby-server
            ffmpegNv
          ];

          config = {
            Cmd = [
              "${pkgs.emby-server}/bin/EmbyServer"
            ];
            User = "1000:1000";
            WorkingDir = "/data";
            ExposedPorts = {
              "8096/tcp" = {};
              "8920/tcp" = {};
            };
          };

          extraCommands = ''
            mkdir -p data etc
            echo 'emby:x:1000:1000::/data:/sbin/nologin' > etc/passwd
            echo 'emby:x:!:1::::::' > etc/shadow
          '';
        };
    };
}

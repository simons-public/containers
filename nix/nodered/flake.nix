{
  description = "Node-RED OCI image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      env = pkgs.buildEnv {
        name = "runtime-env";
        paths = [
          pkgs.nodejs
          pkgs.nodePackages.node-red
        ];
      };
    in {
      packages.${system}.image =
        pkgs.dockerTools.buildImage {
          name = "node-red";
          tag = "4.1.2";

          copyToRoot = [
            pkgs.cacert
            pkgs.git
            pkgs.nodejs
            pkgs.nodePackages.node-red
          ];

          config = {
            Cmd = [
              "${pkgs.nodePackages.node-red}/bin/node-red"
              "--userDir"
              "/data"
            ];
            WorkingDir = "/data";
            User = "1000:1000";
            ExposedPorts = {
              "1880/tcp" = {};
            };
            Env = [
                "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
                "NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-bundle.crt"
            ];
            fakeRootRootCommands = ''
              mkdir -p data etc
              echo 'nodered:x:1000:1000::/data:/sbin/nologin' > etc/passwd
              echo 'nodered:x:!:1::::::' > etc/shadow
            '';
          };

        };
    };
}

{
  description = "SPCS CI/CD project";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      perSystem =
        { pkgs, ... }:
        {
          packages = rec {
            default = dockerImage;

            # Basically the example layered image from:
            # https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/docker/examples.nix#L63
            # With the local nginx.conf
            dockerImage =
              let
                nginxConf = pkgs.writeText "nginx.conf" ''
                  user nobody nobody;
                  daemon off;
                  error_log /dev/stdout info;
                  pid /dev/null;
                  events {}

                  http {
                    ${builtins.readFile ./nginx.conf}
                  }
                '';

              in
              pkgs.dockerTools.buildLayeredImage {
                name = "spcs-ci-cd";
                tag = "latest";
                contents = [
                  pkgs.dockerTools.fakeNss
                  pkgs.nginx
                ];

                extraCommands = ''
                  mkdir -p tmp/nginx_client_body

                  # nginx still tries to read this directory even if error_log
                  # directive is specifying another file :/
                  mkdir -p var/log/nginx
                '';

                config = {
                  Cmd = [
                    "nginx"
                    "-c"
                    nginxConf
                  ];
                  ExposedPorts = {
                    "80/tcp" = { };
                  };
                };
              };

            # Pass through skopeo for pinning
            inherit (pkgs) skopeo;

          };

          devShells.default = pkgs.mkShell {
            packages = [
              pkgs.skopeo
              pkgs.buildah
              pkgs.act
            ];
          };
        };
    };
}

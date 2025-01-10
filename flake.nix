{
  description = "SPCS CI/CD project";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.devshell.flakeModule
      ];
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

          devshells.default = {
            env = [
              {

                name = "DEMO_DOCKER_PORT";
                value = 8000;
              }
            ];

            commands =
              let
                curl = pkgs.lib.getExe pkgs.curl;
              in
              [
                {
                  help = "run local docker";
                  name = "docker-run-local";
                  command = "docker run --rm -p \${DEMO_DOCKER_PORT}:80 $(docker build -q \${PRJ_ROOT})"; # NOTE: not providing docker in the devshell
                }
                # Requests to /
                # Just to show it works
                {
                  help = "Send sample request to /";
                  name = "demo-request-root";
                  command = "${curl} http://localhost:\${DEMO_DOCKER_PORT}";
                  category = "demo";
                }
                # A sample greeting
                {
                  help = "Send sample request to / as if visiting as a Snowflake user.";
                  name = "demo-request-root-as-a-user";
                  command = ''
                    ${curl} \
                      --header "sf-Context-Current-User: ''${USER}"\
                      http://localhost:''${DEMO_DOCKER_PORT}'';
                  category = "demo";
                }
                # Json endpoint
                {
                  help = "Send sample request to /echo";
                  name = "demo-request-post-echo";
                  command =
                    # bash
                    ''
                      ${curl} \
                        --request POST \
                        --header "Content-Type: application/json" \
                        --data '{"data": [[0, "Hello"]]}' \
                        http://localhost:''${DEMO_DOCKER_PORT}/echo
                    '';
                  category = "demo";
                }
                {
                  help = "Run a hurl-based test";
                  name = "test-hurl";
                  command =
                    # bash
                    ''
                      export HURL_port="''${DEMO_DOCKER_PORT}"
                      export HURL_user="''${USER}"
                      ${pkgs.lib.getExe pkgs.hurl} --test "''${PRJ_ROOT}/hurl-tests/unit-tests"
                    '';
                  category = "test";
                }
              ];
            packages = [
              pkgs.skopeo
              pkgs.buildah
              pkgs.act
              pkgs.hurl
              pkgs.curl
            ];
          };
        };
    };
}

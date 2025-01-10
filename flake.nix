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
                nginxConf = pkgs.writeTextDir "conf/nginx.conf" (builtins.readFile ./nginx.conf);
              in
              pkgs.dockerTools.buildLayeredImage {
                name = "spcs-ci-cd";
                tag = "latest";
                contents = [
                  pkgs.dockerTools.fakeNss
                  pkgs.openresty
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
                    "-p"
                    nginxConf
                  ];
                  ExposedPorts = {
                    "8001/tcp" = { };
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

            commands = [
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
              {
                help = "Run hurl test against service in SPCS";
                name = "test-spcs-hurl";
                command =
                  # bash
                  ''
                    export HURL_auth_token=$($PRJ_ROOT/utils/spcs-jwt-to-auth-token)
                    export HURL_url=''${ENDPOINT_URL}
                    export HURL_expected_user=''${SNOWFLAKE_USER}

                    ${pkgs.lib.getExe pkgs.hurl} --test "''${PRJ_ROOT}"/hurl-tests/integration-tests
                  '';
                category = "test";
              }
            ] ++ (import ./utils/devshell-cmds/demo.nix { inherit pkgs; });
            packages = [
              pkgs.skopeo
              pkgs.buildah
              pkgs.act
              pkgs.hurl
              pkgs.curl
              pkgs.jwt-cli
            ];
          };
        };
    };
}

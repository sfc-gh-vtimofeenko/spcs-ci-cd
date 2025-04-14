{
  description = "SPCS CI/CD project";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";

    # Nixpkgs is pinned to the revision where snowflake-cli==3.5.0 was merged
    # snowflake-cli >= 3.5.0 is needed for spcs commands:
    # https://github.com/snowflakedb/snowflake-cli/releases/tag/v3.5.0
    nixpkgs.url = "github:NixOS/nixpkgs?rev=4e0e69f6b14d6b15e02996ee02ccc8728dcc683a";

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

            # Based on the example layered image from:
            # https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/docker/examples.nix#L63
            # With the local nginx.conf
            dockerImage =
              let
                # writeTextDir produces dir which is what nginx needs for the `-p` flag
                nginxConf = pkgs.writeTextDir "conf/nginx.conf" (builtins.readFile ./nginx.conf);
              in
              pkgs.dockerTools.buildLayeredImage {
                name = "spcs-ci-cd";
                tag = "latest";
                contents = [
                  pkgs.dockerTools.fakeNss
                  pkgs.openresty
                  pkgs.snowflake-cli # actually executed the command
                  pkgs.bash # Provides `sh` for the openresty's shell.run
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
            inherit (pkgs) skopeo snowflake-cli;

          };

          devshells.default = {
            env = [
              {
                name = "DEMO_DOCKER_PORT";
                value = 8001;
              }
            ];

            commands =
              [
                ./utils/devshell-cmds/demo.nix
                ./utils/devshell-cmds/test.nix
                ./utils/devshell-cmds/ci.nix
              ]
              |> map (file: import file { inherit pkgs; })
              |> pkgs.lib.flatten;

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

{ pkgs, ... }:
let
  settings.category = "ci";
  # This is the file name of the docker image as downloaded from GH artifact cache
  settings.ghArtifactName = "artifact/out";
  settings.imageTag = "spcs-ci-cd:latest";
in
[
  {
    help = "Run docker in GH action";
    name = "docker-run";
    command =
      # bash
      ''
        docker load < ${settings.ghArtifactName}
        docker run --rm \
          --detach \
          -p ''${DEMO_DOCKER_PORT}:8001 \
          --platform=linux/amd64 ${settings.imageTag}
      '';
  }
  # The test compute pool should be created independently
  # This command will start the compute pool and block until it's up
  # If the compute pool is already up -- the command will short-circuit to success
  {
    help = "Make sure test compute pool is started";
    name = "snowcli-start-pool-wait-until-started";
    command =
      {
        name = "wait-until-compute-pool-up";
        runtimeInputs = [
          pkgs.snowflake-cli
          pkgs.coreutils-full
        ];
        text = builtins.readFile ../wait-until-compute-pool-up;
      }
      |> pkgs.writeShellApplication
      |> lib.getExe;
  }
  # Creates SPCS service to perform tests against
  # Blocks until service is up or times out
  {
    help = "Set up a temporary service on the test service";
    name = "snowcli-create-test-service";
    command =
      # bash
      ''
        exit 1
      '';
  }
  # Retrieves the temporary service endpoint to be used for tests
  {
    help = "Get the temporary service endpoint";
    name = "snowcli-get-test-service-url";
    command =
      # bash
      ''
        exit 1
      '';
  }
]
# Add category
|> map (cmd: cmd // { inherit (settings) category; })
# Add prefix to command
|> map (cmd: cmd // { name = "${settings.category}-${cmd.name}"; })

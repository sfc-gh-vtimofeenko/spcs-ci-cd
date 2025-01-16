/**
  Commands allow running individual steps from the CI pipeline. Some commands
  also have an inverse of them (create service -> drop service) for faster and
  more pointed resets.
*/
{ pkgs, ... }:
let
  settings.category = "ci";
  # This is the file name of the docker image as downloaded from GH artifact cache
  settings.ghArtifactName = "artifact/out";
  settings.imageTag = "spcs-ci-cd:latest";

  inherit (pkgs) lib;
  snow = lib.getExe pkgs.snowflake-cli;
  jq = lib.getExe pkgs.jq;
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
  rec {
    help = "Push the docker archive into Snowflake";
    name = "skopeo-push-to-snowflake-registry";
    command =
      {
        inherit name;
        runtimeInputs = [
          pkgs.snowflake-cli # for `snow`
          pkgs.skopeo # for `skopeo`
        ];
        text = builtins.readFile ../skopeo-push-to-snowflake-registry;
      }
      |> pkgs.writeShellApplication
      |> lib.getExe;
  }
  # The test compute pool should be created independently
  # This command will start the compute pool and block until it's up
  # If the compute pool is already up -- the command will short-circuit to success
  rec {
    help = "Make sure test compute pool is started";
    name = "start-test-compute-pool-wait-until-up";
    command =
      {
        inherit name;
        runtimeInputs = [
          pkgs.snowflake-cli # `needed for snow`
          pkgs.jq
          pkgs.coreutils-full # needed for `timeout`
        ];
        text = builtins.readFile (./../. + "/${name}");
      }
      |> pkgs.writeShellApplication
      |> lib.getExe;
  }
  # Inverse of the previous command
  {
    help = "Stop the test compute pool";
    name = "stop-test-compute-pool";
    command = ''
      set -x
      snow spcs compute-pool suspend $TEST_COMPUTE_POOL'';
  }

  # Creates SPCS service to perform tests against
  # Blocks until service is up or times out
  rec {
    help = "Set up a temporary service on the test service";
    name = "create-test-service-wait-until-up";
    command =
      {
        inherit name;
        runtimeInputs = [
          pkgs.snowflake-cli # `needed for snow`
          pkgs.jq
          pkgs.coreutils-full # needed for `timeout`
        ];
        text = builtins.readFile (./../. + "/${name}");
      }
      |> pkgs.writeShellApplication
      |> lib.getExe;
  }
  # Retrieves the temporary service endpoint to be used for tests
  {
    help = "Run the test suite against the spcs test service";
    name = "run-tests-against-spcs";
    command =
      # bash
      ''
        export ENDPOINT_URL=$(${snow} spcs service list-endpoints SPCS.CI.CI_CD_TEST_SRV --format=json | ${jq} --raw-output '.[].ingress_url')

        test-spcs-hurl
      '';
  }
]
# Add category
|> map (cmd: cmd // { inherit (settings) category; })
# Add prefix to command
|> map (cmd: cmd // { name = "${settings.category}-${cmd.name}"; })

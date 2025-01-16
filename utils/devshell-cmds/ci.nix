/**
  Commands allow running individual steps from the CI pipeline. Some commands
  also have an inverse of them (create service -> drop service) for faster and
  more pointed resets.
*/
{ pkgs, ... }:
let
  settings.category = "ci";
  inherit (pkgs) lib;
in
[
  rec {
    help = "Run docker in GH action";
    name = "docker-run";
    command =
      {
        inherit name;
        runtimeInputs = [ ];
        text = builtins.readFile (./../. + "/${name}");
      }
      |> pkgs.writeShellApplication
      |> lib.getExe;
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

  {
    help = "Get test service state";
    name = "get-service-state";
    command = "snow spcs service describe $TEST_SERVICE_DB.$TEST_SERVICE_SCHEMA.$TEST_SERVICE_NAME";
  }

  rec {
    help = "Run the test suite against the spcs test service";
    name = "run-tests-against-spcs";
    command =
      {
        inherit name;
        runtimeInputs = [
          pkgs.snowflake-cli # `needed for snow`
          pkgs.jq
          pkgs.hurl
          pkgs.git
        ];
        text = builtins.readFile (./../. + "/${name}");
      }
      |> pkgs.writeShellApplication
      |> lib.getExe;
  }

  rec {
    help = "Tear down service";
    name = "tear-down-service";
    command =
      {
        inherit name;
        runtimeInputs = [
          pkgs.snowflake-cli # `needed for snow`
        ];
        text = builtins.readFile (./../. + "/${name}");
      }
      |> pkgs.writeShellApplication
      |> lib.getExe;
  }
]
# Add category
|> map (cmd: cmd // { inherit (settings) category; })
# Add prefix to command
|> map (cmd: cmd // { name = "${settings.category}-${cmd.name}"; })

/**
  Commands allow running individual steps from the CI pipeline. Some commands
  also have an inverse of them (create service -> drop service) for faster and
  more pointed resets.
*/
{ pkgs, ... }:
let
  settings.category = "ci";
  inherit (pkgs) lib;

  /**
    Function that produces a devshell commands.
    All these commands are basically wrappers around bash utilities that ensure
    runtimeInputs are present.
  */
  mkCmd =
    {
      help,
      name,
      runtimeInputs,
    }:
    {
      inherit help name;
      command =
        {
          inherit name runtimeInputs;
          text = builtins.readFile (./../. + "/${name}");
        }
        |> pkgs.writeShellApplication
        |> lib.getExe;
    };
in
[

  {
    help = "Run docker in GH action";
    name = "docker-run";
    runtimeInputs = [ ];
  }

  {
    help = "Push the docker archive into Snowflake";
    name = "skopeo-push-to-snowflake-registry";
    runtimeInputs = [
      pkgs.snowflake-cli # for `snow`
      pkgs.skopeo # for `skopeo`
    ];
  }

  # The test compute pool should be created independently
  # This command will start the compute pool and block until it's up
  # If the compute pool is already up -- the command will short-circuit to success
  {
    help = "Make sure test compute pool is started";
    name = "start-test-compute-pool-wait-until-up";
    runtimeInputs = [
      pkgs.snowflake-cli # `needed for snow`
      pkgs.jq
      pkgs.coreutils-full # needed for `timeout`
    ];
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
  {
    help = "Set up a temporary service on the test service";
    name = "create-test-service-wait-until-up";
    runtimeInputs = [
      pkgs.snowflake-cli # `needed for snow`
      pkgs.jq
      pkgs.coreutils-full # needed for `timeout`
    ];
  }

  {
    help = "Get test service state";
    name = "get-service-state";
    command = "snow spcs service describe $TEST_SERVICE_DB.$TEST_SERVICE_SCHEMA.$TEST_SERVICE_NAME";
  }

  {
    help = "Run the test suite against the spcs test service";
    name = "run-tests-against-spcs";
    runtimeInputs = [
      pkgs.snowflake-cli # `needed for snow`
      pkgs.jq
      pkgs.hurl
      pkgs.git
      pkgs.jwt-cli # Needed for getting the auth token
    ];
  }

  {
    help = "Tear down service";
    name = "tear-down-service";
    runtimeInputs = [
      pkgs.snowflake-cli # `needed for snow`
    ];
  }
]
# If there is an explicit 'command' attr, then the command is already in expected format
# Otherwise turn it into command
|> map (cmd: if builtins.hasAttr "command" cmd then cmd else mkCmd cmd)
# Add category
|> map (cmd: cmd // { inherit (settings) category; })
# Add prefix to command
|> map (cmd: cmd // { name = "${settings.category}-${cmd.name}"; })

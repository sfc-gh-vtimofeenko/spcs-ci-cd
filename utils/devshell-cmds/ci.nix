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
          pkgs.snowflake-cli # `needed for snow`
          pkgs.coreutils-full # needed for `timeout`
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
        set -x
        SPEC_FILE=$(mktemp)
        trap "rm -f ''${SPEC_FILE}" EXIT

        cat<<EOF >$SPEC_FILE
        spec:
          containers:
            - name: test-service
              image: $REGISTRY_URL/${settings.imageTag}
          endpoints:
            - name: main
              port: $DEMO_DOCKER_PORT
              public: true

        EOF

        ${snow} spcs service create "$TEST_SERVICE_DB.$TEST_SERVICE_SCHEMA.$TEST_SERVICE_NAME" --compute-pool "$TEST_COMPUTE_POOL" --spec-path "$SPEC_FILE"

        # TODO: break on broken service
        # Block until service is "RUNNING"
        DESIRED_STATE="RUNNING"
        SERVICE_START_TIMEOUT="10m"
        timeout "$SERVICE_START_TIMEOUT" bash -c "
        until [[ \"$DESIRED_STATE\" = \$SERVICE_STATE ]]; do
          echo \"Polling service state\"
          export SERVICE_STATE=\$(${snow} spcs service describe $TEST_SERVICE_DB.$TEST_SERVICE_SCHEMA.$TEST_SERVICE_NAME --format=json | jq --raw-output '.[].status')
          echo \"Service $TEST_SERVICE_NAME is \$SERVICE_STATE\"
          sleep 1
        done
        echo \"Done waiting. Service is now \$SERVICE_STATE\"
        "

        # Block until ingress_url is filled (starts with ingress_url)
        SERVICE_ENDPOINT_TIMEOUT="10m"
        timeout "$SERVICE_ENDPOINT_TIMEOUT" bash -c "
        until [[ \$SERVICE_ENDPOINT =~ ".snowflakecomputing.app" ]]; do
          echo \"Polling service endpoint\"
          export SERVICE_ENDPOINT=\$(${snow} spcs service list-endpoints $TEST_SERVICE_DB.$TEST_SERVICE_SCHEMA.$TEST_SERVICE_NAME --format=json | jq --raw-output '.[].ingress_url')
          echo \"Service $TEST_SERVICE_NAME is: \$SERVICE_ENDPOINT\"
          sleep 1
        done
        echo \"Done waiting. Service endpoint: \$SERVICE_ENDPOINT\"
        "

      '';
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

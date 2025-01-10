{ pkgs, ... }:
let
  category = "test";
in
[
  {
    help = "Run a hurl-based test against local service";
    name = "local-hurl";
    command =
      # bash
      ''
        export HURL_port="''${DEMO_DOCKER_PORT}"
        export HURL_user="''${USER}"
        ${pkgs.lib.getExe pkgs.hurl} --test "''${PRJ_ROOT}/hurl-tests/unit-tests"
      '';
  }
  {
    help = "Run a hurl-based test against service in SPCS";
    name = "spcs-hurl";
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
]
# Append category
|> map (cmd: cmd // { inherit category; })
# Add prefix to command
|> map (cmd: cmd // { name = "${category}-${cmd.name}"; })

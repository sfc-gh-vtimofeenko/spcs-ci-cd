{ pkgs, ... }:
let
  curl = pkgs.lib.getExe pkgs.curl;
in
[
  {
    help = "Build using local docker";
    name = "docker-run-local";
    command = ''docker run --rm -p ''${DEMO_DOCKER_PORT}:8001 $(docker build -q ''${PRJ_ROOT})''; # NOTE: not providing docker in the devshell
  }
  {
    help = "Build using nix, run in local docker";
    name = "docker-run-local-nix";
    command = ''
      nix build .#packages.x86_64-linux.dockerImage
      docker load < result
      docker run --rm -p \''${DEMO_DOCKER_PORT}:8001 --platform=linux/amd64 spcs-ci-cd:latest''; # NOTE: not providing docker in the devshell
  }
  # Requests to /
  # Just to show it works
  {
    help = "Send sample request to /";
    name = "demo-request-root";
    command = "${curl} http://localhost:\${DEMO_DOCKER_PORT}";
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
  }
]
|> map (c: c // { category = "demo"; })

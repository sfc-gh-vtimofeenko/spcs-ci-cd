_:
let
  settings.category = "ci";
  settings.ghArtifactName = "artifact";
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
]
# Add category
|> map (cmd: cmd // { inherit (settings) category; })
# Add prefix to command
|> map (cmd: cmd // { name = "${settings.category}-${cmd.name}"; })

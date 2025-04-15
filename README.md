This is a repository to complement a [blog post][post] on building and pushing container
images into Snowpark Container Services.

It contains a sample container Dockerfile and a set of GitHub actions.

[post]: https://medium.com/@vladimir.timofeenko/snowpark-container-services-ci-cd-building-and-pushing-images-2109f54eaa99

# Contents of this repository

- [A sample web service](./src/)
- Unit tests
- Integration tests
- CI/CD pipeline:
    - Builds an image
    - Runs tests that don't need a database connection
    - Pushes image to Snowflake
    - Creates a test SPCS service
    - Runs tests that do need a database connection
    - Deploys a "production" instance of the service if tests pass

This repo uses Nix to manage the dependencies, the scripts and provide a guided
developer experience.

While Nix helps, it's not a hard requirement. The scripts are written in bash,
so they can be used without Nix, assuming the dependencies are available in
environment.

# Local setup

This section guides through the setup of the development environment on a local
machine.

The local development environment executes the same scripts as the CI does.

## Without Nix

Install following dependencies:

- Docker (or a different container runtime)
- [hurl](https://hurl.dev/) to run tests
- [Snowflake CLI][snowcli-install]

## Common section

1. Set up Snowflake:
    - Image repository
    - Compute pool
    - User with READ and WRITE privileges on the image repository that is logging
      in through key-pair authentication

    See the "[Common setup][common-setup]" page in SPCS tutorials for a detailed walkthrough.

2. Set up a [Snowflake CLI connection][snowcli-connection]
3. Set up environment variables:

    - `DEMO_DOCKER_PORT`: the port that container runtime will map to the
      webservice in the container. Nix will provide a default value of 8001.

# Local demo of the service

## Running the service

To run the service, execute the following command:

<!-- `$ cat $(which docker-run-local) | tail -n +4` as shell -->

```shell
docker run --rm -p ${DEMO_DOCKER_PORT}:8001 $(docker build -q ${PRJ_ROOT:-$(git rev-parse --show-toplevel)})
```

The `PRJ_ROOT` part is there just to make sure `docker build` finds the
Dockerfile.

This will start the service locally. The only limitation is that the local
service will not talk to Snowflake.

## Interactive demo using curl

Once the service is up, you can use curl to call the endpoints.

Showing default response on `/`:

<!-- `$ cat $(which demo-request-root) | tail -n +4 | perl -pe 's;/nix.*?/bin/;;' ` as shell -->

```shell
curl http://localhost:${DEMO_DOCKER_PORT}
```

Which will result in:

<!-- `$ demo-request-root` as shell -->

```shell
Hello world
```

Pretending to a be a Snowflake user:

<!-- `$ cat $(which demo-request-root-as-a-user) | tail -n +4 | perl -pe 's;/nix.*?/bin/;;' ` as shell -->

```shell
curl \
  --header "sf-Context-Current-User: ${USER}"\
  http://localhost:${DEMO_DOCKER_PORT}
```

Results in:

<!-- `$ demo-request-root-as-a-user` as shell -->

```shell
Hello vtimofeenko
```

Where `{USERNAME}` is the name of the local user on your machine.

Calling the `/echo` endpoint:

<!-- `$ cat $(which demo-request-post-echo) | tail -n +4 | perl -pe 's;/nix.*?/bin/;;' ` as shell -->

```shell
curl \
  --request POST \
  --header "Content-Type: application/json" \
  --data '{"data": [[0, "Hello"]]}' \
  http://localhost:${DEMO_DOCKER_PORT}/echo
```

<!-- `$ demo-request-post-echo` as shell -->

```shell
{"data":[[0,"Endpoint says: 'Hello'"]]}
```

## Running unit tests against the local service instance

This repository contains tests that represent an abstract test suite. The ones
that can run against a local instance of the service are [here][local-tests].

To run them:

<!-- `$ cat $(which test-local-hurl) | tail -n +4 | perl -pe 's;/nix.*?/bin/;;'` as shell -->

```shell
export HURL_port="${DEMO_DOCKER_PORT}"
export HURL_user="${USER}"
hurl --test "${PRJ_ROOT}/hurl-tests/unit-tests"
```

<!-- `$ test-local-hurl 2>&1 | perl -pe 's;^.*unit-tests/;;'` as shell -->

```shell
echo.hurl: Success (1 request(s) in 3 ms)
hello.hurl: Success (2 request(s) in 4 ms)
--------------------------------------------------------------------------------
Executed files:    2
Executed requests: 3 (500.0/s)
Succeeded files:   2 (100.0%)
Failed files:      0 (0.0%)
Duration:          6 ms

```

# CI/CD pipeline

The reference CI/CD pipeline is implemented using GitHub actions. It does use
some GitHub-specific concepts, but they should be portable to other CI systems.
The workflows are there to provide control for the scripts from the repository.

The runners use the standard `ubuntu-latest` image. Whatever dependencies a step
needs, the step will install.

## Building the image

The build step does not require any authentication into Snowflake. The [workflow
file](.github/workflows/end-to-end-1-build.yml) creates a docker image as an
archive and stores it as a GitHub artifact.

An alternative implementation could use a container repository that is built
into the CI/CD system, but the code would become less portable.

[common-setup]: https://docs.snowflake.com/en/developer-guide/snowpark-container-services/tutorials/common-setup
[snowcli-install]: https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation/installation
[snowcli-connection]: https://docs.snowflake.com/en/developer-guide/snowflake-cli/connecting/connect
[local-tests]: ./hurl-tests/unit-tests

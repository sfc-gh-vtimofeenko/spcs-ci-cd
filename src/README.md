This location contains a stand-in for a service that will be running in Snowpark
Container Services. It's implemented using [OpenResty][link] to provide a web
server and a LUA runtime.

The service does not store any data and provides three locations:

- `/`: illustrates how Snowflake passes visiting user's information to the
  service through [headers][spcs-header].

  If visiting user's username is `DEMO_USER`, the page will render `Hello
  DEMO_USER`.

- `/echo`: simple endpoint that conforms with the [function data format][data-format].

  The project uses this endpoint for two purposes:

  1. As a target for unit tests
  <!--TODO: link to test file -->
  2. As a target for a [service function][create-func]
  <!--TODO: check if this is tested. Or if it should be-->

- `/snow`: this endpoint triggers a query to Snowflake.

  The service connects to Snowflake using `snowflake-cli`. Since the goal of
  this service is to provide a reference for a CI/CD pipeline, the actual
  connect implementation does not matter.

  This endpoint is the target for the integration tests.
  <!--TODO: link to test file and the CI pipeline -->

[link]:https://openresty.org/en/
[spcs-header]: https://docs.snowflake.com/en/developer-guide/snowpark-container-services/working-with-services#user-specific-headers-in-ingress-requests
[data-format]: https://docs.snowflake.com/en/sql-reference/external-functions-data-format
[create-func]: https://docs.snowflake.com/en/sql-reference/sql/create-function-spcs

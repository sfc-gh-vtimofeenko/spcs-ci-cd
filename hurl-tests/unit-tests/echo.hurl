# Tests communication to sample /echo endpoint
# The data exchange protocol is specified here:
# https://docs.snowflake.com/en/sql-reference/external-functions-data-format

POST http://localhost:{{port}}/echo
[Options]
variable: row_id=0
variable: request="Hello"
{
    "data": [[{{row_id}}, "{{request}}"]]
}
HTTP 200


[Asserts]
# Just one key should be returned
jsonpath "$.*" count == 1
# Data key should be a collection
jsonpath "$.data" isCollection
# Every item under data should be a collection
jsonpath "$.data[*]" isCollection

# There should be one and only one row in data since the POST had one row
jsonpath "$.data" count == 1
# the response should contain two items
jsonpath "$.data[0]" count == 2
# First item should be same as in request
jsonpath "$.data[0][0]" == {{row_id}}
# Second item should be in expected format (see nginx.conf)
jsonpath "$.data[0][1]" == "Endpoint says: '{{request}}'"

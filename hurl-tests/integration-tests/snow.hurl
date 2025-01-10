# /snow test. Checks that there is one and only one row in the response
GET https://{{url}}/snow
Content-Type: application/x-www-form-urlencoded
Authorization: Snowflake Token="{{auth_token}}"
[Options]
location: true


HTTP 200
[Asserts]
# Just one key should be returned
jsonpath "$.*" count == 1
jsonpath "$[0]['COUNT(C_CUSTOMER_SK)']" == 1

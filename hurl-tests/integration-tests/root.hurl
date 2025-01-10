GET https://{{url}}/
Content-Type: application/x-www-form-urlencoded
Authorization: Snowflake Token="{{auth_token}}"
[Options]
location: true

HTTP 200
[Asserts]
body == "Hello {{expected_user}}"

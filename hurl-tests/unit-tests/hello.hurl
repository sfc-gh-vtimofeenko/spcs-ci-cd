GET http://localhost:{{port}}/
HTTP 200
[Asserts]
body == "Hello world"

GET http://localhost:{{port}}/
sf-Context-Current-User: {{user}}
HTTP 200
[Asserts]
body == "Hello {{user}}"

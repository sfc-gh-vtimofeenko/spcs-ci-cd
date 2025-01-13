# NOTE: /snow endpoint does not work here
FROM openresty/openresty:1.25.3.2-2-alpine-fat
COPY ./nginx.conf /etc/nginx/conf/nginx.conf
RUN [ "apk", "update" ]
RUN [ "apk", "add", "python3-dev" ]
RUN [ "apk", "add", "pipx" ]
RUN [ "pipx", "--global", "install", "snowflake-cli"]
RUN [ "ln", "-s", "/root/.local/bin/snow", "/bin/snow" ]
CMD [ "nginx", "-p", "/etc/nginx" ]

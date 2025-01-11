# NOTE: /snow endpoint does not work here
FROM openresty/openresty:1.25.3.2-0-buster-fat
COPY ./nginx.conf /etc/nginx/conf/nginx.conf
CMD [ "nginx", "-p", "/etc/nginx" ]

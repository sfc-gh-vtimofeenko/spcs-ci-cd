FROM openresty/openresty:1.25.3.2-0-buster-fat
COPY ./nginx.conf /etc/nginx/conf.d/default.conf

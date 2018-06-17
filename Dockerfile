FROM dracoblue/nginx-extras:1.10.1-3
RUN apt-get update
RUN apt-get install lua-cjson lua-lpeg
RUN apt-get install lua5.1
RUN apt-get install -y gettext-base
ADD nginx.conf.template /etc/nginx/nginx.conf.template
RUN mkdir /usr/share/nginx/html/graphiql
ADD graphiql.html.template /usr/share/nginx/html/graphiql/index.template
RUN rm /etc/nginx/sites-enabled/default
ADD src/lua-graphql-hateoas-content.lua /etc/nginx/lua-graphql-hateoas-content.lua
ADD src/lua-graphql-hateoas-header.lua /etc/nginx/lua-graphql-hateoas-header.lua
ADD src/parse-graphql.lua /usr/share/lua/5.1/parse-graphql.lua
ENV NGINX_SERVER_NAME=_ \
    NGINX_SERVER_PORT=80 \
    NGINX_PROXY_PASS=127.0.0.1:1337 \
    NGINX_PROXY_HOST=127.0.0.1 \
    NGINX_LOG_LEVEL=warn \
    HYPERMEDIA_CONTROL_PREFIXES= \
    GRAPHIQL_API_BASE_URL=/api/
EXPOSE 80
CMD envsubst '$$NGINX_PROXY_PASS $$NGINX_SERVER_PORT $$NGINX_SERVER_NAME $$NGINX_LOG_LEVEL $$NGINX_PROXY_HOST $HYPERMEDIA_CONTROL_PREFIXES' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf && envsubst '$$GRAPHIQL_API_BASE_URL' < /usr/share/nginx/html/graphiql/index.template > /usr/share/nginx/html/graphiql/index.html && nginx -g 'daemon off;'

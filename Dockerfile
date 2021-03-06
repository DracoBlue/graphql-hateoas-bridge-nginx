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
    NGINX_PROXY_CACHE=off \
    NGINX_PROXY_CACHE_CHUNK_SIZE=100m \
    NGINX_PROXY_CACHE_SIZE=10g \
    NGINX_PROXY_CACHE_INACTIVE_TIME=60m \
    NGINX_PROXY_PASS=127.0.0.1:1337 \
    NGINX_PROXY_HOST=127.0.0.1 \
    NGINX_ERROR_LOG=/var/log/nginx/error.log \
    NGINX_ACCESS_LOG=/var/log/nginx/access.log \
    NGINX_LUA_CODE_CACHE=on \
    NGINX_LOG_SUBREQUEST=on \
    NGINX_LOG_LEVEL=warn \
    HYPERMEDIA_CONTROL_PREFIXES= \
    DEBUG_MODE=off \
    GRAPHIQL_API_BASE_URL=/api/
EXPOSE 80
CMD bash -c "envsubst '\$DEBUG_MODE \$HYPERMEDIA_CONTROL_PREFIXES `env | grep '^NGINX_' | cut -f 1 -d '=' | sed 's/NGINX/\$NGINX/g' | tr -s ' '`' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf && envsubst '\$GRAPHIQL_API_BASE_URL' < /usr/share/nginx/html/graphiql/index.template > /usr/share/nginx/html/graphiql/index.html && nginx -g 'daemon off;'"

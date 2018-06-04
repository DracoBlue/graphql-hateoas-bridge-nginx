#!/usr/bin/env bash
DOCKER_ARGS="--rm"
if [ "$1" == "daemon" ]
then
	DOCKER_ARGS="-d"
fi

if [ "$2" == "" ]
then
  cp .travis/Dockerfile .
else
  echo "FROM dracoblue/nginx-extras:$2" > Dockerfile
  cat .travis/Dockerfile | grep -v "^FROM " >> Dockerfile
fi

docker build -t graphql-hateoas-bridge-nginx . && docker run $DOCKER_ARGS -v`pwd`/src/lua-graphql-hateoas-content.lua:/etc/nginx/lua-graphql-hateoas-content.lua -v`pwd`/src/lua-graphql-hateoas-header.lua:/etc/nginx/lua-graphql-hateoas-header.lua -v`pwd`/src/parse-graphql.lua:/usr/share/lua/5.1/parse-graphql.lua -v`pwd`/tests:/var/www/html -p127.0.0.1:4777:4777 -p127.0.0.1:4778:4778 -it graphql-hateoas-bridge-nginx
exit $?

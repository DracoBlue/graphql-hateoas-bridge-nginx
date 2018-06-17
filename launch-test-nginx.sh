#!/usr/bin/env bash
DOCKER_ARGS="--rm"
if [ "$1" == "daemon" ]
then
	DOCKER_ARGS="-d"
fi

DOCKER_FILE_NAME=.travis/Dockerfile

if [ "$2" == "" ]
then
  echo "Use the default version"
else
  echo "Use a specific version: $2"
  DOCKER_FILE_NAME=${DOCKER_FILE_NAME}-$2
  echo "FROM dracoblue/nginx-extras:$2" > $DOCKER_FILE_NAME
  cat .travis/Dockerfile | grep -v "^FROM " >> $DOCKER_FILE_NAME
fi

docker build -f $DOCKER_FILE_NAME -t graphql-hateoas-bridge-nginx . && docker run $DOCKER_ARGS -v`pwd`/src/lua-graphql-hateoas-content.lua:/etc/nginx/lua-graphql-hateoas-content.lua -v`pwd`/src/lua-graphql-hateoas-header.lua:/etc/nginx/lua-graphql-hateoas-header.lua -v`pwd`/src/parse-graphql.lua:/usr/share/lua/5.1/parse-graphql.lua -v`pwd`/tests:/var/www/html -p127.0.0.1:4777:4777 -p127.0.0.1:4778:4778 -it graphql-hateoas-bridge-nginx
exit $?

# graphql-hateoas-brige-nginx

* Latest Release: [![GitHub version](https://badge.fury.io/gh/DracoBlue%2Fgraphql-hateoas-brige-nginx.png)](https://github.com/DracoBlue/lua-native-ssi-nginx/releases)
* Build Status: [![Build Status](https://secure.travis-ci.org/DracoBlue/graphql-hateoas-brige-nginx.png?branch=master)](http://travis-ci.org/DracoBlue/lua-native-ssi-nginx)

This is an effort to add a generic graphql endpoint before a hateoas compliant api with nginx's lua module.

## Features:

1. graphql read queries
2. alias
3. variables
4. arguments (mapped to url parameters or uri templates)
5. fragments

## Unsupported Graphql Features:

1. graphql schema
2. graphql mutations

## Media Types:

  - [hal](http://stateless.co/hal_specification.html) (links, embedded, but no curries yet)


## Installation & Usage with Docker-Compose

Given you have an HAL-API at `https://hateoas-notes.herokuapp.com/api/hal`. Split up
the url in:

1. proxy pass: `https://hateoas-notes.herokuapp.com`
2. proxy host: `hateoas-notes.herokuapp.com`
3. and graphiql api base path: `/api/hal`

If your hypermedia controls in HAL are prefixed like this:
  `https://hateoas-notes.herokuapp.com/rels/note` 
and you would like to use `note` directly, then set:
  `HYPERMEDIA_CONTROL_PREFIXES=https://hateoas-notes.herokuapp.com/rels/`

Setup the `docker-compose.yml` like this:
```yaml
services:
  nginx:
    image: dracoblue/graphql-hateoas-bridge-nginx
    environment:
      - "NGINX_PROXY_PASS=https://hateoas-notes.herokuapp.com"
      - "NGINX_PROXY_HOST=hateoas-notes.herokuapp.com"
      - "GRAPHIQL_API_BASE_URL=/api/hal"
      - "HYPERMEDIA_CONTROL_PREFIXES=https://hateoas-notes.herokuapp.com/rels/"
    ports:
      - "80:80"
```

Open [http://localhost/graphiql/](http://localhost/graphiql/?query=%7B%0A%20%20notes%20%7B%0A%20%20%20%20note%20%7B%0A%20%20%20%20%20%20title%2C%0A%20%20%20%20%20%20tags%2C%0A%20%20%20%20%20%20owner%20%7B%0A%20%20%20%20%20%20%20%20username%0A%20%20%20%20%20%20%7D%0A%20%20%20%20%7D%0A%20%20%7D%0A%7D) with
```graphql
{
  notes(limit: 2, offset: 1) {
    note {
      title,
      tags,
      owner {
        username
      }
    }
  }
}
```

and receive:
```json
{
  "data": {
    "notes": {
      "note": [
        {
          "tags": [
            "books"
          ],
          "title": "REST in Practice",
          "owner": {
          	"username": "test"
          }
        },
        {
          "tags": [
            "books"
          ],
          "title": "Domain Driven Design",
          "owner": {
          	"username": "test"
          }
        }
      ]
    }
  }
}
```

## Manual Installation & Usage with Nginx + Lua

Install nginx-extras (to enable lua in nginx), lua-cjson lua-lpeg and lua5.1.

```console
$ apt-get install lua-cjson lua-lpeg lua5.1 nginx-extras
```

If you started with a location like this:

``` txt
location / {
	proxy_pass http://127.0.0.1:4777;
	# add your proxy_* parameters and so on here
}
```

you have to replace it with something like this:

``` txt
location /graphql-hateoas-brige-api-gateway/ {
	internal;
	rewrite ^/graphql-hateoas-brige-api-gateway/(.*)$ /$1  break;
	proxy_pass http://127.0.0.1:4777;
	# add your proxy_* parameters and so on here
}

location / {
	set $graphql_hateoas_api_gateway_prefix "/graphql-hateoas-brige-api-gateway";
	content_by_lua_file "/etc/nginx/lua-graphql-hateoas-content.lua";
	header_filter_by_lua_file "/etc/nginx/lua-graphql-hateoas-header.lua";
}
```

The `graphql-hateoas-brige-api-gateway` location is necessary to use e.g. nginx's caching layer and such things.

## Development

To run the tests locally launch:

``` console
$ ./launch-test-nginx.sh
...
Successfully built 72a844684987
2016/09/11 11:34:02 [alert] 1#0: lua_code_cache is off; this will hurt performance in /etc/nginx/sites-enabled/port-4778-app.conf:12
nginx: [alert] lua_code_cache is off; this will hurt performance in /etc/nginx/sites-enabled/port-4778-app.conf:12
```

Now the nginx processes are running with docker.

Now you can run the tests like this:

``` console
$ ./run-tests.sh
  [OK] hal_include
```

## FAQ

### Subrequests hang when used with graphql-hateoas-bridge-nginx

The following setup is often used, to avoid buffering on disk:

``` text
proxy_buffer_size          16k;
proxy_buffering         on;
proxy_max_temp_file_size 0;
```

but it will result in hanging requests, if the response size is bigger then 16k.

That's why you should either use (means: disable buffering at all):

``` text
proxy_buffer_size          16k;
proxy_buffering         off;
```

or (means: store up to 1024m in temp file)

``` text
proxy_buffer_size          16k;
proxy_buffering         on;
proxy_max_temp_file_size 1024m;
```

to work around this issue.


## TODOs

See <https://github.com/DracoBlue/graphql-hateoas-brige-nginx/issues> for all open TODOs.

## Changelog

See [CHANGELOG.md](./CHANGELOG.md).

## License

This work is copyright by DracoBlue (<http://dracoblue.net>) and licensed under the terms of MIT License.

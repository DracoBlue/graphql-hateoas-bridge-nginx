ngx.log(ngx.ERR, "headers?")
ngx.log(ngx.ERR, tostring(ngx.headers_sent))
ngx.log(ngx.ERR, tostring(ngx.ctx.res))
if not ngx.headers_sent and ngx.ctx.res
then
    ngx.log(ngx.ERR, "headers!")

    local requestHeaders = {}

    local sanatizeHeaderFieldName = function(headerFieldName)
        return string.gsub(string.lower(headerFieldName), "_", "-")
    end

    for k, v in pairs(ngx.req.get_headers()) do
        k = sanatizeHeaderFieldName(k)
        requestHeaders[k] = v
    end

    for k, v in pairs(ngx.ctx.res.header) do
        ngx.header[k] = v
    end
    if ngx.ctx.graphqlSubRequestsCount then
        ngx.header["X-Graphql-Sub-Requests"] = ngx.ctx.graphqlSubRequestsCount
    end
    if ngx.ctx.graphqlIncludesCount then
        ngx.header["X-Graphql-Includes"] = ngx.ctx.graphqlIncludesCount
    end
    if ngx.ctx.graphqlDepth then
        ngx.header["X-Graphql-Depth"] = ngx.ctx.graphqlDepth
    end
    ngx.header["Content-Length"] = nil
    if ngx.ctx.etag then
        ngx.header["ETag"] = ngx.ctx.etag
        local ifNoneMatch = ngx.req.get_headers()["If-None-Match"] or nil
        ngx.log(ngx.DEBUG, "If-None-Match: ", ifNoneMatch)
        ngx.log(ngx.DEBUG, "ETag: ", ngx.ctx.etag)

        if ifNoneMatch == ngx.ctx.etag
        then
            ngx.header["Content-Length"] = 0
            ngx.exit(ngx.HTTP_NOT_MODIFIED)
            return
        end
    end
end

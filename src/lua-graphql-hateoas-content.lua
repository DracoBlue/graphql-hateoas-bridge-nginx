
local parseGraphQL = require 'parse-graphql'

--[[

curl -s 'http://localhost:4778/api/hal/' -H 'Content-Type: application/json' --data-binary '{  notes(limit: 2, offset: 1) { _links { up { title } }, note { title, id, owner { username, id} } }}' | json

 ]]

local prefix = ngx.var.graphql_hateoas_api_gateway_prefix
local totalGraphqlSubRequestsCount = 0
local totalGraphqlIncludesCount = 0
local totalGraphqlDepth = 0

local cjson = (function()
    local hasCjson, cjson = pcall(function()
        return require "cjson.safe"
    end)

    if (hasCjson)
    then
        return cjson
    end

    return false
end)()

ngx.req.read_body()

local requestBody = ngx.req.get_body_data()

ngx.log(ngx.DEBUG, "requestBody: " .. requestBody)

local jsonParsedRequestBody, errorMessage = cjson.decode(requestBody)

if (jsonParsedRequestBody and jsonParsedRequestBody.query)
then
    ngx.log(ngx.DEBUG, "requestBody was JSON!")
    requestBody = jsonParsedRequestBody.query
end

local graphQLRequest = parseGraphQL(requestBody)


ngx.log(ngx.DEBUG, cjson.encode(graphQLRequest))
ngx.log(ngx.DEBUG, cjson.encode(graphQLRequest.definitions[1].selectionSet.selections[1].name))

local hcPrefix = "https://hateoas-notes.herokuapp.com/rels/"

extractSelectionSetFromValue = function(body, selectionSet)
    local root = {}
    for _, selection in ipairs(selectionSet.selections) do
        ngx.log(ngx.DEBUG, "selection (kind:" .. selection.kind .. ", name:" .. selection.name.value .. ")")

        if (selection.kind == "field") then
            if (body[selection.name.value]) then
                if (selection.selectionSet) then
                    root[selection.name.value] = extractSelectionSetFromValue(body[selection.name.value], selection.selectionSet)
                else
                    root[selection.name.value] = body[selection.name.value]
                end
            end
            local linkValue = body["_links"] and (body["_links"][selection.name.value] or body["_links"][hcPrefix .. selection.name.value])
--            local embeddedValue = body["_embedded"] and (body["_embedded"][selection.name.value] or body["_embedded"][hcPrefix .. selection.name.value])


            ngx.log(ngx.DEBUG, "selection arguments: " .. cjson.encode(selection.arguments))

            local argumentsQueryParts = {}
            if (selection.arguments) then
                for _, argument in ipairs(selection.arguments) do
                    argumentsQueryParts[argument.name.value] = argument.value.value
                end
            end

            if (linkValue) then
                if (linkValue[1]) then
                    -- poor mans check for an array!
                    root[selection.name.value] = {}
                    for _, linkValueItem in ipairs(linkValue) do
                        ngx.log(ngx.DEBUG, "link Value: " .. cjson.encode(linkValueItem))
                        local subRequestUri = linkValueItem["href"]
                        if (selection.arguments) then
                            subRequestUri = subRequestUri .. "?" .. ngx.encode_args(argumentsQueryParts)
                        end
                        table.insert(root[selection.name.value], mapRequestToGraphQLSelectionSet(subRequestUri, selection.selectionSet))
                    end
                else
                    ngx.log(ngx.DEBUG, "link Value: " .. cjson.encode(linkValue))
                    local subRequestUri = linkValue["href"]
                    if (selection.arguments) then
                        subRequestUri = subRequestUri .. "?" .. ngx.encode_args(argumentsQueryParts)
                    end
                    root[selection.name.value] = mapRequestToGraphQLSelectionSet(subRequestUri, selection.selectionSet)
                end
            end
        end
    end
    return root
end
mapResponseToGraphQLSelectionSet = function(requestUrl, res, selectionSet)
    ngx.log(ngx.DEBUG, "res.body: " .. res.body)

    local body, errorMessage = cjson.decode(res.body)

    if (errorMessage)
    then
        ngx.log(ngx.ERR, "invalid json from " .. requestUrl)
        return root
    end

    ngx.log(ngx.DEBUG, "selections set: " .. cjson.encode(selectionSet))
    ngx.log(ngx.DEBUG, "parsed json: " .. cjson.encode(body))

    return extractSelectionSetFromValue(body, selectionSet)
end

mapRequestToGraphQLSelectionSet = function(subRequestUri, selectionSet)
    ngx.log(ngx.DEBUG, "subRequestUri: " .. subRequestUri)
    ngx.log(ngx.DEBUG, "subRequestUrl: " .. prefix .. subRequestUri)

    totalGraphqlSubRequestsCount = totalGraphqlSubRequestsCount + 1
    totalGraphqlIncludesCount = totalGraphqlIncludesCount + 1
    local subRequestResponse = ngx.location.capture(
        prefix .. subRequestUri, {
        method = ngx["HTTP_GET"]
    }
    )

    return mapResponseToGraphQLSelectionSet(subRequestUri, subRequestResponse, selectionSet)
end

local rootResponse = ngx.location.capture(
    prefix .. ngx.var.request_uri, {
    method = ngx["HTTP_GET"]
}
)

local body = mapResponseToGraphQLSelectionSet(ngx.var.request_uri, rootResponse, graphQLRequest.definitions[1].selectionSet)

local responseBody = cjson.encode({data = body })

local md5 = ngx.md5(responseBody)
ngx.ctx.etag = '"' .. md5 .. '"'
ngx.ctx.graphqlSubRequestsCount = totalGraphqlSubRequestsCount
ngx.ctx.graphqlIncludesCount = totalGraphqlIncludesCount
ngx.ctx.graphqlDepth = totalGraphqlDepth

ngx.ctx.res = rootResponse
ngx.print(responseBody)
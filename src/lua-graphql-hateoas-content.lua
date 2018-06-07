
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
local variables = {}

ngx.log(ngx.DEBUG, "requestBody: " .. requestBody)

local jsonParsedRequestBody, errorMessage = cjson.decode(requestBody)

if (jsonParsedRequestBody and jsonParsedRequestBody.query)
then
    ngx.log(ngx.DEBUG, "requestBody was JSON: store query!")
    requestBody = jsonParsedRequestBody.query
end

if (jsonParsedRequestBody and jsonParsedRequestBody.variables)
then
    ngx.log(ngx.DEBUG, "requestBody was JSON: store variables!")
    variables = jsonParsedRequestBody.variables
end

local graphQLRequest = parseGraphQL(requestBody)


ngx.log(ngx.ERR, cjson.encode(graphQLRequest))

local fragmentDefinitionSelections = {}
local variableDefinitions = {}

local parseFragmentDefinitions = function(graphQLRequest)
    for _, definition in ipairs(graphQLRequest.definitions) do
        if (definition.kind == "fragmentDefinition") then
            ngx.log(ngx.ERR, "found fragmentdefinition: " .. definition.name.value)
            fragmentDefinitionSelections[definition.name.value] = definition.selectionSet
        end
    end
end

parseFragmentDefinitions(graphQLRequest)

local parseVariableDefinitions = function(graphQLRequest)
    for _, definition in ipairs(graphQLRequest.definitions) do
        if (definition.variableDefinitions) then
            for _, variableDefinition in ipairs(definition.variableDefinitions) do
                if (variableDefinition.kind == "variableDefinition") then
                    ngx.log(ngx.ERR, "found variableDefinition: " .. variableDefinition.variable.name.value)
                    variableDefinitions[variableDefinition.variable.name.value] = variableDefinition
                end
            end
        end
    end
end

parseVariableDefinitions(graphQLRequest)

evaluateTemplateUriAndAppendArguments = function(templateUri, arguments)
    local usedArguments = {}
    local evaluatedUri = templateUri:gsub("{(.+)}", function(input)
        if (arguments[input] ~= nil) then
            usedArguments[input] = true
            return arguments[input]
        end
        return "{" .. input .. "}"
    end)
    local appendArguments = {}

    for key, value in pairs(arguments) do
        if (usedArguments[key] == nil) then
            appendArguments[key] = value
        end
    end

    local appendQueryString = ngx.encode_args(appendArguments)

    if (ngx.encode_args(appendArguments) ~= "") then
        if (evaluatedUri:find("?")) then
            return evaluatedUri .. "&" .. appendQueryString
        end
        return evaluatedUri .. "?" .. appendQueryString
    end

    return evaluatedUri
end

local hcPrefix = "https://hateoas-notes.herokuapp.com/rels/"

extractSelectionSetFromValue = function(body, selectionSet)
    local root = {}
    for _, selection in ipairs(selectionSet.selections) do
        local keyName = selection.name.value

        if selection.alias and selection.alias.kind == "alias" then
            keyName = selection.alias.name.value
        end
    
        ngx.log(ngx.ERR, "selection (kind:" .. selection.kind .. ", name:" .. selection.name.value .. ", keyName: " .. keyName .. ")")

        ngx.log(ngx.ERR, selection.kind)
        if (selection.kind == "fragmentSpread" and fragmentDefinitionSelections[selection.name.value]) then
            -- FIXME: check typeCondition, too!
            local fragmentSpreadRoot = extractSelectionSetFromValue(body, fragmentDefinitionSelections[selection.name.value])
            for key, value in pairs(fragmentSpreadRoot) do
                root[key] = value
            end
        end
        if (selection.kind == "field") then
            if (body[selection.name.value]) then
                if (selection.selectionSet) then
                    root[keyName] = extractSelectionSetFromValue(body[selection.name.value], selection.selectionSet)
                else
                    root[keyName] = body[selection.name.value]
                end
            end
            local linkValue = body["_links"] and (body["_links"][selection.name.value] or body["_links"][hcPrefix .. selection.name.value])
            local embeddedValue = body["_embedded"] and (body["_embedded"][selection.name.value] or body["_embedded"][hcPrefix .. selection.name.value])

            ngx.log(ngx.DEBUG, "selection arguments: " .. cjson.encode(selection.arguments))

            local argumentsQueryParts = {}
            if (selection.arguments) then
                for _, argument in ipairs(selection.arguments) do
                    if (argument.kind == "argument")
                    then
                        if (argument.value.kind == "variable")
                        then
                            argumentsQueryParts[argument.name.value] = variableDefinitions[argument.value.name.value] and variables[argument.value.name.value]
                        else
                            argumentsQueryParts[argument.name.value] = argument.value.value
                        end
                    end
                end
            end
            if (embeddedValue) then
                if (embeddedValue[1]) then
                    -- poor mans check for an array!
                    root[keyName] = {}
                    for _, embeddedValueItem in ipairs(embeddedValue) do
                        table.insert(root[keyName],extractSelectionSetFromValue(embeddedValueItem, selection.selectionSet))
                    end
                else
                    root[keyName] = extractSelectionSetFromValue(embeddedValue, selection.selectionSet)
                end
            elseif (linkValue) then
                if (linkValue[1]) then
                    -- poor mans check for an array!
                    root[keyName] = {}
                    for _, linkValueItem in ipairs(linkValue) do
                        ngx.log(ngx.DEBUG, "link Value: " .. cjson.encode(linkValueItem))
                        local subRequestUri = linkValueItem["href"]
                        subRequestUri = evaluateTemplateUriAndAppendArguments(subRequestUri, argumentsQueryParts)
                        table.insert(root[keyName], mapRequestToGraphQLSelectionSet(subRequestUri, selection.selectionSet))
                    end
                else
                    ngx.log(ngx.DEBUG, "link Value: " .. cjson.encode(linkValue))
                    local subRequestUri = linkValue["href"]
                    subRequestUri = evaluateTemplateUriAndAppendArguments(subRequestUri, argumentsQueryParts)
                    root[keyName] = mapRequestToGraphQLSelectionSet(subRequestUri, selection.selectionSet)
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
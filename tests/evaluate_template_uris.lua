ngx = {
    log = function() end,
    var = { graphql_hateoas_api_gateway_prefix = "/graphql-hateoas-api-gateway", request_uri = "/lua-test", request_method = "GET" },
    req = { read_body = function() end, get_body_data = function() return "{ title, id }" end },
    location = { capture = function() return { body = "" } end },
    md5 = function(str) return str end,
    ctx = {},
    print = function() end,
    encode_args = function(arguments)
        local queryStringParts = {}
        for key, value in pairs(arguments) do
            table.insert(queryStringParts, tostring(key) .. "=" .. tostring(value))
        end
        return table.concat(queryStringParts, "&")
    end
}

local assertTable = function(actual, expected, message)
    for k,v in pairs(actual)
    do
        assert(expected[k] == v, message or ("for key '" .. tostring(k) .. "' '" .. tostring(expected[k]) .. "' expected, but '" .. tostring(v) .. "' given"))
    end
    for k,v in pairs(expected)
    do
        assert(actual[k] == v, message or ("for key '" .. tostring(k) .. "' '" .. tostring(v) .. "' expected, but '" .. tostring(actual[k]) .. "' given"))
    end
end

local assertEquals = function(actual, expected, message)
    assert(actual == expected, message or ("expected '" .. tostring(expected) .. "' expected, but '" .. tostring(actual) .. "' given"))
end

dofile("./src/lua-graphql-hateoas-content.lua")

assertEquals(evaluateTemplateUriAndAppendArguments("http://example.org/{id}", {id = 1}), "http://example.org/1")
assertEquals(evaluateTemplateUriAndAppendArguments("http://example.org/{id}", {id = 1, limit = 2}), "http://example.org/1?limit=2")
assertEquals(evaluateTemplateUriAndAppendArguments("http://example.org/{id}?offset=1", {id = 1, limit = 2}), "http://example.org/1?offset=1&limit=2")

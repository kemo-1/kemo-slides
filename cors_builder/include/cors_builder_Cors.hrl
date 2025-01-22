-record(cors, {
    allow_origin :: gleam@option:option(cors_builder:origin()),
    expose_headers :: gleam@set:set(binary()),
    max_age :: gleam@option:option(integer()),
    allow_credentials :: gleam@option:option(boolean()),
    allow_methods :: gleam@set:set(gleam@http:method()),
    allow_headers :: gleam@set:set(binary())
}).

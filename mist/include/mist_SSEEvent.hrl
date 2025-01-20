-record(sse_event, {
    id :: gleam@option:option(binary()),
    event :: gleam@option:option(binary()),
    data :: gleam@string_tree:string_tree()
}).

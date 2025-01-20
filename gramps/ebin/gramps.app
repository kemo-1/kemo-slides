{application, gramps, [
    {vsn, "3.0.0"},
    {applications, [gleam_crypto,
                    gleam_erlang,
                    gleam_http,
                    gleam_stdlib]},
    {description, "A Gleam HTTP and WebSocket helper library"},
    {modules, [gramps@debug,
               gramps@http,
               gramps@websocket,
               gramps@websocket@compression]},
    {registered, []}
]}.

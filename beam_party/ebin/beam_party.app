{application, beam_party, [
    {vsn, "1.0.0"},
    {applications, [bravo,
                    chip,
                    gleam_erlang,
                    gleam_http,
                    gleam_json,
                    gleam_otp,
                    gleam_stdlib,
                    mist,
                    simplifile]},
    {description, ""},
    {modules, [beam_party,
               websocket@pubsub,
               websocket@websocket]},
    {registered, []}
]}.

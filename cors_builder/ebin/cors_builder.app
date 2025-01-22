{application, cors_builder, [
    {vsn, "2.0.3"},
    {applications, [gleam_http,
                    gleam_stdlib,
                    mist,
                    wisp]},
    {description, "A CORS Builder, performing validation and injection of CORS for misp, wisp and any framework!"},
    {modules, [cors_builder]},
    {registered, []}
]}.

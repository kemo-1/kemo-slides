{application, lamb, [
    {vsn, "0.6.1"},
    {applications, [gleam_erlang,
                    gleam_stdlib]},
    {description, "ETS and MatchSpecs for Gleam."},
    {modules, [lamb,
               lamb@query,
               lamb@query@term]},
    {registered, []}
]}.

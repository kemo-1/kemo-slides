{application, bravo, [
    {vsn, "0.0.0"},
    {applications, [gleam_erlang,
                    gleam_stdlib]},
    {description, "Comprehensive ETS bindings for Gleam."},
    {modules, [bravo,
               bravo@bag,
               bravo@dbag,
               bravo@internal@bindings,
               bravo@internal@master,
               bravo@internal@new_options,
               bravo@oset,
               bravo@uset]},
    {registered, []}
]}.

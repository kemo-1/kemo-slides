-record(websocket_actor_state, {
    pubsub :: gleam@erlang@process:subject(chip:message(websocket@websocket:custom_websocket_message(), websocket@pubsub:channel())),
    channel :: websocket@pubsub:channel(),
    table :: bravo@uset:u_set(binary(), binary())
}).

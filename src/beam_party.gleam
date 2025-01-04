import bravo
import bravo/uset
import gleam/bytes_tree
import gleam/dynamic
import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import gleam/io
import gleam/option.{None, Some}
import mist
import websocket/pubsub.{Awareness, Doc, Ydoc}
import websocket/websocket

fn new_response(status: Int, body: String) {
  response.new(status)
  |> response.set_body(body |> bytes_tree.from_string |> mist.Bytes)
}

pub fn main() {
  let table = case
    uset.file2tab(
      "database/db.ets",
      True,
      fn(table) { table |> dynamic.string },
      fn(table) { table |> dynamic.string },
    )
  {
    Ok(table) -> table
    Error(_) -> {
      let assert Ok(table) = uset.new("doc", bravo.Public)
      table
    }
  }
  let assert Ok(pubsub) = pubsub.start()
  let assert Ok(_) =
    mist.new(fn(request) {
      let response = case request.path_segments(request) {
        ["api", x] -> {
          case x {
            "doc" ->
              websocket.start(request, pubsub, Ydoc(x), Some(table)) |> Ok
            "awareness" -> websocket.start(request, pubsub, Ydoc(x), None) |> Ok

            _ -> new_response(404, "Not found") |> Ok
          }
        }

        _ -> {
          new_response(404, "Not found") |> Ok
        }
      }

      case response {
        Ok(response) -> response
        Error(error) -> {
          io.print_error(error)
          new_response(500, "Internal Server Error")
        }
      }
    })
    |> mist.bind("0.0.0.0")
    |> mist.port(3000)
    |> mist.start_http_server

  process.sleep_forever()
}

import bravo
import bravo/uset
import gleam/bytes_tree
import gleam/dynamic
import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/string
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
        ["api", ..] -> {
          let new_list =
            request.path_segments(request)
            |> list.drop(1)
            |> string.join("/")

          // let channel =
          //   new_list
          //   |> list.index_fold("/", fn(start, string, index) {
          //     string.(start, string)
          //     // string.append(new_list,string)
          //   })
          //   |> Ydoc

          websocket.start(request, pubsub, Ydoc(new_list), table) |> Ok
        }

        _ -> {
          new_response(
            404,
            "this is a websocket server it dosen't accept get requests",
          )
          |> Ok
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
    |> mist.port(8000)
    |> mist.start_http_server

  process.sleep_forever()
}

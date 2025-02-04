import bravo/uset.{type USet}
import chip
import gleam/dynamic/decode
import gleam/erlang/process.{type Subject, Normal}
import gleam/json

import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io

import gleam/option.{type Option, None, Some}
import gleam/otp/actor.{type Next, Stop}
import mist.{
  type Connection, type ResponseData, type WebsocketConnection,
  type WebsocketMessage, Custom, Text,
}
import websocket/pubsub.{type Channel, publish, subscribe}

pub type CustomWebsocketMessage {
  Connect(user_subject: Subject(CustomWebsocketMessage))
  SendToAll(message: String, save_to_db: Bool)
  Disconnect
}

pub type Event {
  Event(message: String)
}

pub opaque type WebsocketActorState {
  WebsocketActorState(
    pubsub: Subject(chip.Message(CustomWebsocketMessage, Channel)),
    channel: Channel,
    table: USet(String, String),
  )
}

pub fn start(
  req: Request(Connection),
  pubsub: Subject(chip.Message(CustomWebsocketMessage, Channel)),
  channel: Channel,
  table: USet(String, String),
) -> Response(ResponseData) {
  mist.websocket(
    request: req,
    on_init: fn(connection) {
      io.println("New connection initialized")
      let ws_subject = process.new_subject()
      let new_selector =
        process.new_selector()
        |> process.selecting(ws_subject, fn(x) { x })

      subscribe(pubsub, channel, ws_subject)

      let state = WebsocketActorState(pubsub:, channel:, table:)

      case channel {
        pubsub.Ydoc(document_name) -> {
          case uset.lookup(table, document_name) {
            Error(err) -> {
              io.debug(err)
              io.println_error(
                "Error:  document couldn't be found making a new doc",
              )
            }
            Ok(doc_value) -> {
              // let #(_, value) = doc_value
              send_client_text(connection, doc_value)
            }
          }
        }
        _ -> panic
      }

      #(state, Some(new_selector))
    },
    on_close: fn(_state) { io.println("A connection was closed") },
    handler: handle_message,
  )
}

fn handle_message(
  state: WebsocketActorState,
  connection: WebsocketConnection,
  message: WebsocketMessage(CustomWebsocketMessage),
) -> Next(CustomWebsocketMessage, WebsocketActorState) {
  case message {
    Custom(message) ->
      case message {
        Connect(_subject) -> {
          actor.continue(state)
        }
        SendToAll(message, save_to_db) -> {
          case save_to_db {
            True -> {
              case state.channel {
                pubsub.Ydoc(document_name) -> {
                  case uset.insert(state.table, document_name, message) {
                    Ok(_) -> {
                      case
                        uset.tab2file(
                          state.table,
                          ".data/db.ets",
                          True,
                          True,
                          False,
                        )
                      {
                        Ok(_) -> {
                          // io.println(
                          //   "document has been saved to file sucessfully",
                          // )
                          Nil
                        }
                        Error(_err) -> {
                          // io.debug(err)
                          // io.println(
                          //   "document couldn't be saved to file sucessfully because ^^^",
                          // )
                          Nil
                        }
                      }
                      // io.println("document has been saved in memory")
                      send_client_text(connection, message)
                      actor.continue(state)
                    }
                    Error(_err) -> {
                      // io.debug(err)
                      // io.println("document couldn't be insert to database")
                      send_client_text(connection, message)

                      actor.continue(state)
                    }
                  }
                }
                _ -> panic
              }
            }
            False -> {
              send_client_text(connection, message)
              actor.continue(state)
            }
          }
        }
        Disconnect -> {
          Stop(Normal)
        }
      }

    Text(message) -> {
      let doc_decoder = {
        use name <- decode.field("doc", decode.string)
        decode.success(name)
      }

      case json.parse(from: message, using: doc_decoder) {
        Ok(doc) -> {
          let json = json.to_string(json.object([#("doc", json.string(doc))]))
          publish(state.pubsub, state.channel, SendToAll(json, True))
        }
        Error(_) ->
          publish(state.pubsub, state.channel, SendToAll(message, False))
      }

      actor.continue(state)
    }
    _ -> {
      Stop(Normal)
    }
  }
}

fn send_client_text(connection: WebsocketConnection, value: String) -> Nil {
  let _ = mist.send_text_frame(connection, value)
  Nil
}

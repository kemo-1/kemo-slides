import bravo/uset.{type USet}
import chip
import gleam/erlang/process.{type Subject, Normal}

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
  SendToAll(message: String)
  Disconnect
}

pub type Event {
  Event(message: String)
}

pub opaque type WebsocketActorState {
  WebsocketActorState(
    pubsub: Subject(chip.Message(CustomWebsocketMessage, Channel)),
    channel: Channel,
    table: Option(USet(String, String)),
  )
}

pub fn start(
  req: Request(Connection),
  pubsub: Subject(chip.Message(CustomWebsocketMessage, Channel)),
  channel: Channel,
  table: Option(USet(String, String)),
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
      let state = WebsocketActorState(pubsub:, channel: channel, table: table)

      case table {
        Some(doc_table) -> {
          case uset.lookup(doc_table, "doc") {
            Error(err) -> {
              io.debug(err)
              io.println_error("Error:  document couldn't be found")
            }
            Ok(doc_value) -> {
              // let #(_, value) = doc_value
              send_client_text(connection, doc_value)
            }
          }
        }
        None -> Nil
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
        SendToAll(message) -> {
          case state.table {
            Some(table) -> {
              case uset.insert(table, "doc", message) {
                Ok(_) -> {
                  case
                    uset.tab2file(table, "database/db.ets", True, True, True)
                  {
                    Ok(_) ->
                      io.println("document has been saved to file sucessfully")
                    Error(err) -> {
                      io.debug(err)
                      io.println(
                        "document couldn't be saved to file sucessfully because ^^^ ",
                      )
                    }
                  }
                  io.println("document has been saved in memory")
                  send_client_text(connection, message)
                  actor.continue(state)
                }
                Error(err) -> {
                  io.debug(err)
                  io.println("document couldn't be saved to file")

                  actor.continue(state)
                }
              }
            }
            None -> {
              send_client_text(connection, message)
              actor.continue(state)
            }
          }

          send_client_text(connection, message)
          actor.continue(state)
        }
        Disconnect -> {
          Stop(Normal)
        }
      }

    Text(value) -> {
      publish(state.pubsub, state.channel, SendToAll(value))
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

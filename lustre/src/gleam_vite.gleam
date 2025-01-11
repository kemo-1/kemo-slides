import gleam/dynamic
import gleam/io
import gleam/javascript/array
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import lustre
import lustre/attribute
import sketch/media
import sketch/size

// import sketch/lustre
import sketch/lustre/element.{type Element}
import sketch/lustre/element/html

// import lustre/element/html
import lustre/event
import sketch
import sketch/lustre as sketch_lustre

// import lustre/element/html
// import lustre/event
import gleam/uri.{type Uri}
import lustre/effect.{type Effect}

import modem

@external(javascript, "./storage.ffi.ts", "insert_note")
pub fn insert_note(note: String) -> array.Array(String)

@external(javascript, "./storage.ffi.ts", "delete_note")
pub fn remove_note(note_index: Int) -> array.Array(String)

@external(javascript, "./storage.ffi.ts", "get_notes")
pub fn get_notes() -> array.Array(String)

@external(javascript, "./storage.ffi.ts", "get_room")
pub fn get_room() -> Result(array.Array(String), Nil)

@external(javascript, "./storage.ffi.ts", "init_connection")
pub fn init_connection() -> Nil

@external(javascript, "./storage.ffi.ts", "create_room")
pub fn create_room(room_name: String, room_password: String) -> Nil

// fn do_insert_note(string: String) {
//   effect.from(fn(_dispatch) { insert_note(string) })
// }

fn add_note(note: String) -> Effect(Msg) {
  effect.from(fn(dispatch) {
    let notes = {
      insert_note(note)
      |> array.to_list
    }
    dispatch(NotesChanged(notes))
  })
}

fn delete_note(note_index: Int) -> Effect(Msg) {
  effect.from(fn(dispatch) {
    let notes = {
      remove_note(note_index)
      |> array.to_list
    }
    dispatch(NotesChanged(notes))
  })
}

fn do_init_connection() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    init_connection()
    let notes = {
      get_notes() |> array.to_list
    }

    dispatch(NotesChanged(notes))
  })
}

fn do_create_roon(room_name: String, room_password: String) {
  effect.from(fn(dispatch) {
    create_room(room_name, room_password)
    dispatch(RoomExists(Room(name: room_name, password: room_password)))

    Nil
  })
}

fn do_get_room() {
  effect.from(fn(dispatch) {
    modem.init(on_url_change)
    case get_room() {
      Ok(array) -> {
        let room = {
          array
          |> array.to_list
        }

        case room |> list.first {
          Ok(name) -> {
            case room |> list.last {
              Ok(password) -> dispatch(RoomExists(Room(name:, password:)))
              Error(_) -> Nil
            }
          }
          Error(_) -> Nil
        }
      }
      Error(_) -> Nil
    }
    // let notes = {
    //   get_notes()
    //   |> array.to_list
    // }
    // dispatch(NotesChanged(notes))

    Nil
  })
}

fn do_get_saved_room() {
  effect.from(fn(dispatch) {
    modem.init(on_url_change)
    case get_room() {
      Ok(array) -> {
        let room = {
          array
          |> array.to_list
        }

        case room |> list.first {
          Ok(name) -> {
            case room |> list.last {
              Ok(password) -> dispatch(SavedRoomExists(Room(name:, password:)))
              Error(_) -> Nil
            }
          }
          Error(_) -> Nil
        }
      }
      Error(_) -> Nil
    }
    // let notes = {
    //   get_notes()
    //   |> array.to_list
    // }
    // dispatch(NotesChanged(notes))

    Nil
  })
}

pub type Route {
  Url(String)
}

fn on_url_change(uri: Uri) -> Msg {
  case uri.path_segments(uri.path) {
    [x] -> OnRouteChange(Url(x))
    _ -> OnRouteChange(Url(""))
  }
}

pub fn main() {
  let assert Ok(cache) = sketch.cache(strategy: sketch.Ephemeral)

  sketch_lustre.node()
  |> sketch_lustre.compose(view, cache)
  |> lustre.application(init, update, _)
  |> lustre.start(
    "#app",
    Model(
      route: Url(""),
      note_name: "",
      notes: [],
      room_password: None,
      room_name: None,
      room: None,
      saved_room: None,
    ),
  )
}

// MODEL -----------------------------------------------------------------------

fn init(model) -> #(Model, Effect(Msg)) {
  #(model, do_get_room())
}

pub type Room {
  Room(name: String, password: String)
}

pub type Model {
  Model(
    route: Route,
    room_password: Option(String),
    note_name: String,
    notes: List(String),
    room_name: Option(String),
    room: Option(Room),
    saved_room: Option(Room),
  )
}

pub type Msg {
  OnRouteChange(Route)
  InputChanged(String)
  NotesChanged(List(String))
  AddNote
  DeleteNote(Int)
  CreateRoom
  RoomNameInputChanged(String)
  RoomPasswordInputChanged(String)
  RoomExists(Room)
  ExitRoom
  SavedRoomExists(Room)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    SavedRoomExists(room) -> #(
      Model(..model, saved_room: Some(room)),
      effect.none(),
    )
    RoomNameInputChanged(room_name) ->
      case room_name {
        "" -> #(model, effect.none())
        "/" -> #(model, effect.none())
        _ -> #(Model(..model, room_name: Some(room_name)), effect.none())
      }
    RoomPasswordInputChanged(room_password) ->
      case room_password {
        "" -> #(model, effect.none())
        "/" -> #(model, effect.none())
        _ -> #(
          Model(..model, room_password: Some(room_password)),
          effect.none(),
        )
      }

    RoomExists(room) -> #(
      Model(..model, room: Some(room)),
      do_init_connection(),
    )
    CreateRoom -> {
      case model.room_name {
        Some(room_name) -> {
          case model.room_password {
            Some(room_password) -> #(
              model,
              do_create_roon(room_name, room_password),
            )
            None -> #(model, effect.none())
          }
        }
        None -> #(model, effect.none())
      }
    }
    ExitRoom -> #(Model(..model, room: None), do_get_saved_room())
    OnRouteChange(route) -> #(Model(..model, route:), effect.none())
    InputChanged(note_name) -> {
      case note_name {
        "" -> #(model, effect.none())
        "/" -> #(model, effect.none())
        _ -> #(Model(..model, note_name:), effect.none())
      }
    }
    AddNote -> {
      case model.note_name {
        "" -> #(model, effect.none())
        "/" -> #(model, effect.none())
        note_name -> #(Model(..model, note_name: ""), add_note(note_name))
      }
    }
    NotesChanged(notes) -> #(Model(..model, notes:), effect.none())
    DeleteNote(note_index) -> #(model, delete_note(note_index))
  }
}

fn view(model: Model) {
  let content_updated = fn(event) -> Result(Msg, List(dynamic.DecodeError)) {
    use detail <- result.try(dynamic.field("detail", dynamic.dynamic)(event))
    use notes <- result.try(dynamic.field("notes", dynamic.list(dynamic.string))(
      detail,
    ))

    Ok(NotesChanged(notes))
  }

  html.div(sketch.class([]), [], case model.route {
    Url(document_name) -> {
      case document_name {
        "" -> {
          case model.room {
            None -> {
              [
                html.div(sketch.class([]), [], [html.text("Enter room name")]),
                html.input(sketch.class([]), [
                  attribute.type_("text"),
                  event.on_input(RoomNameInputChanged),
                ]),
                html.div(sketch.class([]), [], [
                  html.text("Enter room password"),
                ]),
                html.input(sketch.class([]), [
                  attribute.type_("password"),
                  event.on_input(RoomPasswordInputChanged),
                ]),
                html.button(sketch.class([]), [event.on_click(CreateRoom)], [
                  html.text("create or join a room"),
                ]),
                case model.saved_room {
                  Some(room) -> {
                    html.div(sketch.class([]), [], [
                      html.text("Rooms"),
                      html.button(
                        sketch.class([]),
                        [event.on_click(RoomExists(room))],
                        [
                          html.text("room name: " <> room.name),
                          html.text("room password: " <> room.password),
                        ],
                      ),
                    ])
                  }
                  None -> {
                    html.div(sketch.class([]), [], [
                      html.text("no saved rooms found"),
                    ])
                  }
                },
              ]
            }
            Some(room) -> {
              [
                html.div(
                  sketch.class([]),
                  [
                    attribute.id("notes-container"),
                    event.on("content-update", content_updated),
                  ],
                  [
                    html.input(sketch.class([]), [
                      attribute.type_("text"),
                      attribute.value(model.note_name),
                      event.on_input(InputChanged),
                      attribute.style([#("color", "black")]),
                    ]),
                    html.button(sketch.class([]), [event.on_click(AddNote)], [
                      html.text("add a new note"),
                    ]),
                    html.div(sketch.class([]), [], [
                      html.text("your room name is \"" <> room.name <> "\""),
                    ]),
                    html.div(sketch.class([]), [], [
                      html.text(
                        "your room password is \"" <> room.password <> "\"",
                      ),
                    ]),
                    html.div(sketch.class([]), [], [
                      html.button(sketch.class([]), [event.on_click(ExitRoom)], [
                        html.text("exit room"),
                      ]),
                    ]),
                    html.div(sketch.class([]), [], [
                      html.text(
                        "make sure you have the same password and name on your other devices",
                      ),
                    ]),
                  ],
                ),
                element.fragment(
                  model.notes
                  |> list.index_map(fn(note, index) {
                    html.div(sketch.class([]), [], [
                      html.button(
                        sketch.class([]),
                        [event.on_click(DeleteNote(index))],
                        [html.text("x")],
                      ),
                      html.button(
                        sketch.class([]),
                        [event.on_click(OnRouteChange(Url(note)))],
                        [html.text(note)],
                      ),
                    ])
                  }),
                ),
              ]
            }
          }
        }
        _ -> {
          [
            html.div(container(), [attribute.class("editor-container")], [
              html.div(slides(), [attribute.class("slides-element")], []),
              element.element(
                "collaborative-editor",
                editor(),
                [
                  attribute.class("editor-element"),
                  attribute.attribute("document-name", document_name),
                ],
                [],
              ),
            ]),
          ]
        }
      }
    }
  })
}

fn container() {
  sketch.class([
    sketch.display("flex"),
    sketch.height(size.vh(95)),
    sketch.media(media.max_width(size.px(757)), [
      sketch.flex_direction("column"),
    ]),
  ])
}

fn slides() {
  sketch.class([sketch.flex("1")])
}

fn editor() {
  sketch.class([
    sketch.flex("1"),
    sketch.overflow_y("scroll"),
    sketch.scrollbar_color("#44616e"),
    sketch.scrollbar_width("10px"),
    sketch.media(media.max_width(size.px(757)), [sketch.margin_top_("auto")]),
  ])
}

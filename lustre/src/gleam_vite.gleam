import gleam/dynamic
import gleam/io
import gleam/javascript/array
import gleam/list
import gleam/result
import lustre
import lustre/attribute

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

fn do_get_notes() {
  effect.from(fn(dispatch) {
    modem.init(on_url_change)
    let notes = {
      get_notes()
      |> array.to_list
    }
    dispatch(NotesChanged(notes))

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
  |> lustre.start("#app", Model(route: Url(""), note_name: "", notes: []))
}

// MODEL -----------------------------------------------------------------------

fn init(model) -> #(Model, Effect(Msg)) {
  #(model, do_get_notes())
}

pub type Model {
  Model(route: Route, note_name: String, notes: List(String))
}

pub type Msg {
  OnRouteChange(Route)
  InputChanged(String)
  NotesChanged(List(String))
  AddNote
  DeleteNote(Int)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
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
    io.debug("notes")
    Ok(NotesChanged(notes))
  }

  html.div(sketch.class([]), [], case model.route {
    Url(document_name) -> {
      case document_name {
        "" -> {
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
        _ -> {
          [
            element.element(
              "collaborative-editor",
              sketch.class([]),
              [attribute.attribute("document-name", document_name)],
              [],
            ),
          ]
        }
      }
    }
  })
}

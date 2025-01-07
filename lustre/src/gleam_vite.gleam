import gleam/dynamic
import gleam/io
import gleam/javascript/array
import gleam/list
import gleam/result
import lustre
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

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

// MAIN ------------------------------------------------------------------------
pub type Route {
  Url(String)
}

fn on_url_change(uri: Uri) -> Msg {
  case uri.path_segments(uri.path) {
    [x] -> OnRouteChange(Url(x))
    // ["note_2"] -> OnRouteChange(Note2)
    _ -> OnRouteChange(Url(""))
  }
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) =
    lustre.start(app, "#app", Model(route: Url(""), note_name: "", notes: []))

  Nil
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

fn view(model: Model) -> Element(Msg) {
  let content_updated = fn(event) -> Result(Msg, List(dynamic.DecodeError)) {
    use detail <- result.try(dynamic.field("detail", dynamic.dynamic)(event))
    use notes <- result.try(dynamic.field("notes", dynamic.list(dynamic.string))(
      detail,
    ))

    io.debug("notes")

    Ok(NotesChanged(notes))
  }

  html.div([], case model.route {
    Url(document_name) -> {
      case document_name {
        "" -> {
          [
            html.div(
              [
                attribute.id("notes-container"),
                event.on("content-update", content_updated),
              ],
              [
                html.input([
                  attribute.type_("text"),
                  attribute.value(model.note_name),
                  event.on_input(InputChanged),
                  attribute.style([#("color", "black")]),
                ]),
                html.button([event.on_click(AddNote)], [
                  html.text("add a new note"),
                ]),
              ],
            ),
            element.fragment(
              model.notes
              |> list.index_map(fn(note, index) {
                html.div([], [
                  html.button([event.on_click(DeleteNote(index))], [
                    html.text("x"),
                  ]),
                  html.button([event.on_click(OnRouteChange(Url(note)))], [
                    html.text(note),
                  ]),
                ])
              }),
            ),
          ]
        }
        _ -> {
          [
            element.element(
              "collaborative-editor",
              [attribute.attribute("document-name", document_name)],
              [],
            ),
          ]
        }
      }
    }
  })
}
// VIEW ------------------------------------------------------------------------

// fn view(model: Model) -> Element(Msg) {
//   let _styles = [
//     #("width", "100vw"),
//     #("height", "100vh"),
//     #("padding", "1rem"),
//   ]
//   let _count = int.to_string(model)

//   divider([], [
//     divider([], [
//       element.element(
//         "collaborative-editor",
//         [attribute.attribute("document-name", "demo")],
//         [],
//       ),
//     ]),
//   ])
// }

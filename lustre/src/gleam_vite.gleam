import gleam/int
import lustre
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

// import lustre/element/html
// import lustre/event
import gleam/uri.{type Uri}
import lustre/effect.{type Effect}
import lustre/ui/divider.{divider, margin}
import modem

// MAIN ------------------------------------------------------------------------
pub type Route {
  Note1
  Note2
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Note1)

  Nil
}

// MODEL -----------------------------------------------------------------------

fn init(route) -> #(Route, Effect(Msg)) {
  #(route, modem.init(on_url_change))
}

fn on_url_change(uri: Uri) -> Msg {
  case uri.path_segments(uri.path) {
    ["note_1"] -> OnRouteChange(Note1)
    ["note_2"] -> OnRouteChange(Note2)
    _ -> OnRouteChange(Note1)
  }
}

pub type Msg {
  OnRouteChange(Route)
}

fn update(_, msg: Msg) -> #(Route, Effect(Msg)) {
  case msg {
    OnRouteChange(route) -> #(route, effect.none())
  }
}

fn view(route: Route) -> Element(Msg) {
  html.div([], [
    html.nav([], [
      html.a([attribute.href("/note_1")], [element.text("Go to note 1")]),
      html.br([]),
      html.a([attribute.href("/note_2")], [element.text("Go to note_2")]),
    ]),
    // case route {
    //   Note1 ->
    //     element.element(
    //       "collaborative-editor",
    //       [attribute.attribute("document-name", "Note1")],
    //       [],
    //     )

    //   Note2 ->
    //     element.element(
    //       "collaborative-editor",
    //       [attribute.attribute("document-name", "Note2")],
    //       [],
    //     )

    //   NotFound -> html.h1([], [element.text("You're on Note2")])
    // },
    element.element(
      "collaborative-editor",
      [
        attribute.attribute("document-name", case route {
          Note1 -> "note_1"
          Note2 -> "note_2"
        }),
      ],
      [],
    ),
  ])
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

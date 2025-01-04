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
  Wibble
  Wobble
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Wibble)

  Nil
}

// MODEL -----------------------------------------------------------------------

fn init(route) -> #(Route, Effect(Msg)) {
  #(route, modem.init(on_url_change))
}

fn on_url_change(uri: Uri) -> Msg {
  case uri.path_segments(uri.path) {
    ["wibble"] -> OnRouteChange(Wibble)
    ["wobble"] -> OnRouteChange(Wobble)
    _ -> OnRouteChange(Wibble)
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
      html.a([attribute.href("/wibble")], [element.text("Go to wibble")]),
      html.br([]),
      html.a([attribute.href("/wobble")], [element.text("Go to wobble")]),
    ]),
    // case route {
    //   Wibble ->
    //     element.element(
    //       "collaborative-editor",
    //       [attribute.attribute("document-name", "wibble")],
    //       [],
    //     )

    //   Wobble ->
    //     element.element(
    //       "collaborative-editor",
    //       [attribute.attribute("document-name", "wobble")],
    //       [],
    //     )

    //   NotFound -> html.h1([], [element.text("You're on wobble")])
    // },
    element.element(
      "collaborative-editor",
      [
        attribute.attribute("document-name", case route {
          Wibble -> "wibble"
          Wobble -> "wobble"
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

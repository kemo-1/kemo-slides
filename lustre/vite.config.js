import gleam from "vite-gleam";
import wasm from "vite-plugin-wasm";
import topLevelAwait from "vite-plugin-top-level-await";

export default {
    build: {
        target: "esnext"
    },
    plugins: [


        wasm(), topLevelAwait(), gleam()],
    // server: {
    //     proxy: {
    //         '/doc': {
    //             target: 'ws://localhost:3000',
    //             ws: true,
    //         },
    //         '/awareness': {
    //             target: 'ws://localhost:3000',
    //             ws: true,
    //         }
    //     }
    // }

}

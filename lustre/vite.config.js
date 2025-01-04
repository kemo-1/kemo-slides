import gleam from "vite-gleam";

export default {

    plugins: [gleam()],
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

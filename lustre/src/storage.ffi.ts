import { fromUint8Array, toUint8Array } from 'js-base64';
import * as Y from "yjs"
import { IndexeddbPersistence } from 'y-indexeddb'
import * as awarenessProtocol from 'y-protocols/awareness.js'
import { WebrtcProvider } from 'y-webrtc';



//@ts-ignore
import { Ok, Error } from './gleam.mjs'

export function init_connection() {
    const room = localStorage.getItem("room")

    if (room) {
        let yDoc = new Y.Doc()
        //@ts-ignore
        window.yarray = yDoc.getArray('root')
        let obj = JSON.parse(room)

        new IndexeddbPersistence(obj.name + obj.password, yDoc)
        const provider = new WebrtcProvider(obj.name + obj.password, yDoc, { signaling: ['ws://localhost:4444'], password: obj.password })

        //@ts-ignore
        // provider.awareness = awareness



        // socket.onmessage = (event) => {
        //     let json = JSON.parse(event.data)
        //     let doc = json.doc
        //     let awareness = json.awareness

        //     if (doc !== undefined) {
        //         const binaryEncoded = toUint8Array(doc)
        //         Y.applyUpdate(yDoc, binaryEncoded)
        //     }
        //     if (awareness !== undefined) {
        //         const binaryEncoded = toUint8Array(awareness)
        //         //@ts-ignore
        //         awarenessProtocol.applyAwarenessUpdate(provider.awareness, binaryEncoded, '')
        //     }
        // }


        yDoc.on('update', () => {

            // if (socket.readyState === WebSocket.OPEN) {
            //     //@ts-ignore
            //     const documentState = Y.encodeStateAsUpdate(yDoc)
            //     const binaryEncoded = fromUint8Array(documentState)

            //     let doc = { doc: binaryEncoded }
            //     let json = JSON.stringify(doc)
            //     socket.send(json)
            // }

            let event_change = new CustomEvent('content-update', {
                detail: {
                    //@ts-ignore
                    notes: window.yarray.toArray()
                },

                bubbles: true, // Allows the event to bubble up the DOM
                composed: true, // Allows the event to cross the shadow DOM boundary (if present)
            });
            if (document.getElementById("notes-container")) {
                document.getElementById("notes-container")?.dispatchEvent(event_change)
            }


        })

    }
}



//@ts-ignore
// provider.awareness.on('update', ({ added, updated, removed }) => {
//     if (socket.readyState === WebSocket.OPEN) {
//         const changedClients = added.concat(updated).concat(removed)
//         //@ts-ignore
//         const documentAwareness = awarenessProtocol.encodeAwarenessUpdate(provider.awareness, changedClients)
//         const binaryEncoded = fromUint8Array(documentAwareness)

//         let awareness = { awareness: binaryEncoded }
//         let json = JSON.stringify(awareness)
//         socket.send(json)
//     }
// })
export function get_room() {
    const room = localStorage.getItem("room")
    if (room) {
        let obj = JSON.parse(room)
        let array = [obj.name, obj.password]
        return new Ok(array)
    } else {
        return new Error(undefined)
    }

}
export function create_room(name, password) {
    // let name = ""
    // let password = ""
    let obj = { name: name, password: password }
    let string = JSON.stringify(obj)
    localStorage.setItem("room", string)
}
export function insert_note(word: string) {
    //@ts-ignore
    window.yarray.insert(0, [word])
    //@ts-ignore
    return window.yarray.toArray()
}

export function delete_note(index: number) {
    //@ts-ignore
    window.yarray.delete(index, 1)
    //@ts-ignore
    return window.yarray.toArray()
}

export function get_notes() {
    //@ts-ignore
    return window.yarray.toArray()
}


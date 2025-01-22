import { fromUint8Array, toUint8Array } from 'js-base64';

import { LoroDoc } from "loro-crdt";

//@ts-ignore 
import { Ok, Error } from './gleam.mjs'
const loro_doc = new LoroDoc()
import * as Y from 'yjs'
import { IndexeddbPersistence } from 'y-indexeddb';

export async function init_connection() {


    const room = localStorage.getItem("room")
    let documentName

    if (room) {
        let yDoc = new Y.Doc()
        //@ts-ignore
        window.yarray = yDoc.getArray('root')
        let obj = JSON.parse(room)
        const serverUrl = 'hail-past-brochure.glitch.me'
        const socket = new WebSocket(`wss://${serverUrl}/api/${obj.name + obj.password}`)

        new IndexeddbPersistence(obj.name + obj.password, yDoc)
        // const provider = new WebrtcProvider(obj.name + obj.password, yDoc, { signaling: ['wss://mousy-lackadaisical-fuchsia.glitch.me'], password: obj.password })

        //@ts-ignore
        // provider.awareness = awareness



        socket.onmessage = (event) => {
            let json = JSON.parse(event.data)
            let doc = json.doc
            let awareness = json.awareness

            if (doc !== undefined) {
                const binaryEncoded = toUint8Array(doc)
                Y.applyUpdate(yDoc, binaryEncoded)
            }



        }


        yDoc.on('update', () => {

            if (socket.readyState === WebSocket.OPEN) {
                //@ts-ignore
                const documentState = Y.encodeStateAsUpdate(yDoc)
                const binaryEncoded = fromUint8Array(documentState)

                let doc = { doc: binaryEncoded }
                let json = JSON.stringify(doc)
                socket.send(json)
            }

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


    } else {
        localStorage.removeItem("room")
        location.href = '/'

    }

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
}




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

    let obj = { name: name, password: password }
    let string = JSON.stringify(obj)
    localStorage.setItem("room", string)

}
export function insert_note(word: string) {
    window.yarray.insert(0, [word])

    return window.yarray.toArray()
}

export function delete_note(index: number) {

    window.yarray.delete(index, 1)


    return window.yarray.toArray()
}

export async function get_notes() {
    return window.yarray.toArray()
}


import { fromUint8Array, toUint8Array } from 'js-base64';

import { LoroDoc } from "loro-crdt";

//@ts-ignore 
import { Ok, Error } from './gleam.mjs'
const loro_doc = new LoroDoc()
import P2PCF from 'p2pcf'

export async function init_connection() {

    const room = localStorage.getItem("room")
    let documentName

    if (room) {
        let obj = JSON.parse(room)
        documentName = obj.name + obj.password

        let saved_doc = localStorage.getItem("loro_doc")
        const serverUrl = 'hail-past-brochure.glitch.me'
        const Socket = new WebSocket(`wss://${serverUrl}/api/${documentName}`)
        if (saved_doc) {
            let bytes = toUint8Array(saved_doc)
            loro_doc.import(bytes)
            loro_doc.commit()
            await Promise.resolve().then((e => {

                Socket.onopen = () => {


                    let new_bytes = loro_doc.export({ mode: "snapshot" })
                    let string = fromUint8Array(new_bytes)
                    let doc = { doc: string }
                    let json = JSON.stringify(doc)
                    Socket.send(json)

                }



                let event_change = new CustomEvent('content-update', {
                    detail: {
                        notes: loro_doc.getMovableList("root").toArray()
                    },

                    bubbles: true, // Allows the event to bubble up the DOM
                    composed: true, // Allows the event to cross the shadow DOM boundary (if present)
                });

                if (document.querySelector("#notes-container")) {
                    document.querySelector("#notes-container")!.dispatchEvent(event_change)
                }


            }))









        } else {
            let event_change = new CustomEvent('content-update', {
                detail: {
                    notes: loro_doc.getMovableList("root").toArray()
                },

                bubbles: true, // Allows the event to bubble up the DOM
                composed: true, // Allows the event to cross the shadow DOM boundary (if present)
            });

            if (document.querySelector("#notes-container")) {
                document.querySelector("#notes-container")!.dispatchEvent(event_change)
            }
        }


        Socket.onmessage = async (event) => {
            let json = JSON.parse(event.data)
            let loro_doc_string = json.doc

            if (loro_doc_string !== undefined) {
                const binaryEncoded = toUint8Array(loro_doc_string)
                loro_doc.import(binaryEncoded)
                loro_doc.commit()
                await Promise.resolve().then((e => {

                    let event_change = new CustomEvent('content-update', {
                        detail: {
                            notes: loro_doc.getMovableList("root").toArray()
                        },

                        bubbles: true, // Allows the event to bubble up the DOM
                        composed: true, // Allows the event to cross the shadow DOM boundary (if present)
                    });

                    if (document.querySelector("#notes-container")) {
                        document.querySelector("#notes-container")!.dispatchEvent(event_change)
                    }


                }))


            }


        }
        loro_doc.subscribeLocalUpdates(async (event) => {
            loro_doc.commit()
            await Promise.resolve().then((e => {


                let value = loro_doc.getMovableList("root").toArray()
                console.log("content updated", value)
                let bytes = loro_doc.export({ mode: "snapshot" })
                const base64 = fromUint8Array(bytes)

                let event_change = new CustomEvent('content-update', {
                    detail: {
                        notes: loro_doc.getMovableList("root").toArray()
                    },

                    bubbles: true, // Allows the event to bubble up the DOM
                    composed: true, // Allows the event to cross the shadow DOM boundary (if present)
                });

                if (document.querySelector("#notes-container")) {
                    document.querySelector("#notes-container")!.dispatchEvent(event_change)
                }

                if (Socket.readyState === WebSocket.OPEN) {
                    //@ts-ignore

                    let string = fromUint8Array(bytes)
                    let doc = { doc: string }
                    let json = JSON.stringify(doc)
                    Socket.send(json)
                }

                localStorage.setItem("loro_doc", base64)
            }))
        })



    } else {
        localStorage.removeItem("room")
        location.href = '/'

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
    loro_doc.getMovableList("root").insert(0, word)
    loro_doc.commit()

    return loro_doc.getMovableList("root").toArray()
}

export function delete_note(index: number) {

    loro_doc.getMovableList("root").delete(index, 1)
    loro_doc.commit()

    return loro_doc.getMovableList("root").toArray()
}

export async function get_notes() {
    return loro_doc.getMovableList("root").toArray()
}


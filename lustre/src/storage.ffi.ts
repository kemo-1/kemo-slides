import { LoroDoc } from 'loro-crdt/base64'
import { fromUint8Array, toUint8Array } from 'js-base64';
const doc = new LoroDoc();

const lorodocument = localStorage.getItem('loro')!
if (lorodocument) {
    let bytes = toUint8Array(lorodocument)

    doc.import(bytes)
}


const serverUrl = 'localhost:8000'
const documentName = 'main'
const socket = new WebSocket(`ws://${serverUrl}/api/${documentName}`)
doc.subscribe((update => {

    if (socket.readyState === WebSocket.OPEN) {
        let bytes = doc.export({ mode: "snapshot" })
        let string = fromUint8Array(bytes)

        let json_document = { doc: string }
        let json = JSON.stringify(json_document)
        socket.send(json)

        let document_array = doc.toJSON().notes


        let event_change = new CustomEvent('content-update', {
            detail: {
                notes: document_array
            },

            bubbles: true, // Allows the event to bubble up the DOM
            composed: true, // Allows the event to cross the shadow DOM boundary (if present)
        })
        document.getElementById("notes-container")!.dispatchEvent(event_change)

    }


}))
// socket.onmessage( f{})


socket.onmessage = (event) => {
    let json = JSON.parse(event.data)
    let document = json.doc

    let bytes = toUint8Array(document)

    doc.import(bytes)

    localStorage.setItem('loro', document)



    // let custom_event = new CustomEvent("doc-update")
}



const movableList = doc.getMovableList("notes");

export function insert_note(word: string) {
    word.replaceAll(/\/\//g, "/")
    movableList.insert(0, word)


    let document = doc.toJSON()
    let bytes = doc.export({ mode: "snapshot" })
    let string = fromUint8Array(bytes)

    localStorage.setItem('loro', string)


    if (socket.readyState === WebSocket.OPEN) {
        let bytes = doc.export({ mode: "snapshot" })
        let string = fromUint8Array(bytes)

        let document_json = { doc: string }
        let json = JSON.stringify(document_json)
        socket.send(json)
    }


    return document.notes
}

export function delete_note(index: number) {

    movableList.delete(index, 1)


    let document = doc.toJSON()
    let bytes = doc.export({ mode: "snapshot" })
    let string = fromUint8Array(bytes)
    localStorage.setItem('loro', string)



    if (socket.readyState === WebSocket.OPEN) {
        let bytes = doc.export({ mode: "snapshot" })
        let string = fromUint8Array(bytes)

        let document_json = { doc: string }
        let json = JSON.stringify(document_json)
        socket.send(json)
    }


    return document.notes
}

export function get_notes() {
    let array = doc.toJSON().notes
    return array

}

// doc.subscribeLocalUpdates((update => {

//     if (socket.readyState === WebSocket.OPEN) {
//         let string = fromUint8Array(update)

//         let document = { doc: string }
//         let json = JSON.stringify(document)
//         doc.import(update)
//         socket.send(json)
//     }


// }))
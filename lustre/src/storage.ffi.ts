import { fromUint8Array, toUint8Array } from 'js-base64';
import * as Y from "yjs"
import { IndexeddbPersistence } from 'y-indexeddb'
import * as awarenessProtocol from 'y-protocols/awareness.js'


const yDoc = new Y.Doc()
const awareness = new awarenessProtocol.Awareness(yDoc)

const documentName = 'main'

const serverUrl = '192.168.8.118:8000'

const socket = new WebSocket(`ws://${serverUrl}/api/${documentName}`)


const provider = new IndexeddbPersistence(documentName, yDoc)
//@ts-ignore
provider.awareness = awareness

const yarray = provider.doc.getArray('root')


socket.onmessage = (event) => {
    let json = JSON.parse(event.data)
    let doc = json.doc
    let awareness = json.awareness

    if (doc !== undefined) {
        const binaryEncoded = toUint8Array(doc)
        Y.applyUpdate(yDoc, binaryEncoded)
    }
    if (awareness !== undefined) {
        const binaryEncoded = toUint8Array(awareness)
        //@ts-ignore
        awarenessProtocol.applyAwarenessUpdate(provider.awareness, binaryEncoded, '')
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
            notes: yarray.toArray()
        },

        bubbles: true, // Allows the event to bubble up the DOM
        composed: true, // Allows the event to cross the shadow DOM boundary (if present)
    });
    if (document.getElementById("notes-container")) {
        document.getElementById("notes-container")?.dispatchEvent(event_change)
    }


})
//@ts-ignore
provider.awareness.on('update', ({ added, updated, removed }) => {
    if (socket.readyState === WebSocket.OPEN) {
        const changedClients = added.concat(updated).concat(removed)
        //@ts-ignore
        const documentAwareness = awarenessProtocol.encodeAwarenessUpdate(provider.awareness, changedClients)
        const binaryEncoded = fromUint8Array(documentAwareness)

        let awareness = { awareness: binaryEncoded }
        let json = JSON.stringify(awareness)
        socket.send(json)
    }
})


export function insert_note(word: string) {
    yarray.insert(0, [word])
    return yarray.toArray()
}

export function delete_note(index: number) {
    yarray.delete(index, 1)

    return yarray.toArray()
}

export function get_notes() {
    return yarray.toArray()
}


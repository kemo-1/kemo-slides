import { Editor } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'
import Collaboration from '@tiptap/extension-collaboration'
import CollaborationCursor from "@tiptap/extension-collaboration-cursor"
import * as Y from "yjs"
import { IndexeddbPersistence } from 'y-indexeddb'
import { fromUint8Array, toUint8Array } from 'js-base64'
import * as awarenessProtocol from 'y-protocols/awareness.js'
import { Markdown } from 'tiptap-markdown'
import './styles.css'
const COLORS = ["#ffa5a5", "#f9ffa5", "#a9ffa5", "#a5e8ff", "#dfa5ff"]
const NAMES = ["Kemo", "David", "Steven", "Mike", "Kyle"]

const myColor = COLORS[Math.floor(Math.random() * COLORS.length)]
const myName = NAMES[Math.floor(Math.random() * NAMES.length)]
export class CollaborativeEditor extends HTMLElement {
    constructor() {
        super()
        const style = document.createElement('style')
        style.textContent = `
        .tiptap {
            :first-child {
                margin-top: 0;
            }
        
            p.is-editor-empty:first-child::before {
                color: var(--gray-4);
                content: attr(data-placeholder);
                float: left;
                height: 0;
                pointer-events: none;
            }
        
            p {
                word-break: break-all;
            }
        
            .collaboration-cursor__caret {
                border-left: 1px solid #0d0d0d;
                border-right: 1px solid #0d0d0d;
                margin-left: -1px;
                margin-right: -1px;
                pointer-events: none;
                position: relative;
                word-break: normal;
            }
        
            .collaboration-cursor__label {
                border-radius: 3px 3px 3px 0;
                color: #0d0d0d;
                font-size: 18px;
                font-weight: 600;
                left: -1px;
                line-height: normal;
                padding: 0.1rem 0.3rem;
                position: absolute;
                top: -1.4em;
                user-select: none;
                white-space: nowrap;
            }
        }
        `
        document.head.appendChild(style)
    }

    connectedCallback() {
        const editorDiv = document.createElement('div')
        editorDiv.className = 'editor'
        this.appendChild(editorDiv)

        const documentName = this.getAttribute('document-name') || 'default-doc'
        const serverUrl = this.getAttribute('server-url') || 'localhost:3000'

        const yDoc = new Y.Doc()
        const awareness = new awarenessProtocol.Awareness(yDoc)
        const provider = new IndexeddbPersistence(documentName, yDoc)
        //@ts-ignore
        provider.awareness = awareness

        this.initializeConnections(yDoc, provider, documentName, serverUrl)
        this.initializeEditor(yDoc, provider, editorDiv)
    }

    initializeConnections(yDoc, provider, documentName, serverUrl) {
        const docSocket = new WebSocket(`ws://${serverUrl}/api/${documentName}`)
        // const awarenessSocket = new WebSocket(`ws://${serverUrl}/api/awareness`)

        this.setupWebSocketHandlers(docSocket, yDoc, provider)
        this.setupUpdateListeners(yDoc, provider, docSocket)
    }

    setupWebSocketHandlers(docSocket, yDoc, provider) {
        docSocket.onmessage = (event) => {
            let json = JSON.parse(event.data)
            let doc = json.doc
            let awareness = json.awareness

            if (doc !== undefined) {
                const binaryEncoded = toUint8Array(doc)
                Y.applyUpdate(yDoc, binaryEncoded)
            }
            if (awareness !== undefined) {
                const binaryEncoded = toUint8Array(awareness)
                awarenessProtocol.applyAwarenessUpdate(provider.awareness, binaryEncoded, '')
            }

        }

        // awarenessSocket.onmessage = (event) => {
        //     const binaryEncoded = toUint8Array(event.data)
        //     awarenessProtocol.applyAwarenessUpdate(provider.awareness, binaryEncoded, '')
        // }
    }

    setupUpdateListeners(yDoc, provider, docSocket) {
        yDoc.on('update', () => {
            const documentState = Y.encodeStateAsUpdate(yDoc)
            const binaryEncoded = fromUint8Array(documentState)

            if (docSocket.readyState === WebSocket.OPEN) {
                let doc = { doc: binaryEncoded }
                let json = JSON.stringify(doc)
                docSocket.send(json)
            }
        })

        provider.awareness.on('update', ({ added, updated, removed }) => {


            if (docSocket.readyState === WebSocket.OPEN) {
                const changedClients = added.concat(updated).concat(removed)
                const documentAwareness = awarenessProtocol.encodeAwarenessUpdate(provider.awareness, changedClients)
                const binaryEncoded = fromUint8Array(documentAwareness)

                let awareness = { awareness: binaryEncoded }
                let json = JSON.stringify(awareness)
                docSocket.send(json)
            }
        })
    }

    initializeEditor(yDoc, provider, editorDiv) {


        new Editor({
            element: editorDiv,
            extensions: [
                StarterKit.configure({
                    history: false,
                }),
                Markdown.configure({
                    html: true,
                    tightLists: true,
                    tightListClass: 'tight',
                    bulletListMarker: '-',
                    linkify: false,
                    breaks: true,
                    transformPastedText: true,
                    transformCopiedText: true,
                }),
                Collaboration.configure({
                    document: yDoc,
                }),
                CollaborationCursor.configure({
                    provider: provider,
                    user: {
                        name: myName,
                        color: myColor,
                    },
                }),
            ],
        })
    }
}
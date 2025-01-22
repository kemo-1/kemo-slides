import { Editor } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'
import Collaboration from '@tiptap/extension-collaboration'
import CollaborationCursor from "@tiptap/extension-collaboration-cursor"
import * as Y from "yjs"
import { IndexeddbPersistence } from 'y-indexeddb'
import { fromUint8Array, toUint8Array } from 'js-base64'
import * as awarenessProtocol from 'y-protocols/awareness.js'
// import { Markdown } from 'tiptap-markdown'

import '../../node_modules/reveal.js/dist/reveal.css'
import './theme.css'
import './styles.css'
import RevealMenu from './menu/menu.esm.js'
import Reveal from 'reveal.js/dist/reveal.esm';
//@ts-ignore 
import Markdown from 'reveal.js/plugin/markdown/markdown.esm.js';
import { Markdown as MarkdownTiptap } from 'tiptap-markdown';
import Notes from 'reveal.js/plugin/notes/notes.esm.js';
//@ts-ignore
import FsFx from 'reveal.js-fsfx/plugin/fsfx/fsfx.esm.js';
import { HocuspocusProvider } from '@hocuspocus/provider'
import { WebrtcProvider } from 'y-webrtc'

const COLORS = ["#ffa5a5", "#f9ffa5", "#a9ffa5", "#a5e8ff", "#dfa5ff"]
const NAMES = ["Kemo", "David", "Steven", "Mike", "Kyle"]

const myColor = COLORS[Math.floor(Math.random() * COLORS.length)]
const myName = NAMES[Math.floor(Math.random() * NAMES.length)]



export class CollaborativeEditor extends HTMLElement {
    editor: Editor

    static get observedAttributes() {
        return ['document-name', 'server-url']
    }

    constructor() {
        super()
        // const style = document.createElement('style')
        // style.textContent = `
        // .tiptap {
        //     :first-child {
        //         margin-top: 0;
        //     }

        //     p.is-editor-empty:first-child::before {
        //         color: var(--gray-4);
        //         content: attr(data-placeholder);
        //         float: left;
        //         height: 0;
        //         pointer-events: none;
        //     }

        //     p {
        //         word-break: break-all;
        //     }

        //     .collaboration-cursor__caret {
        //         border-left: 1px solid #0d0d0d;
        //         border-right: 1px solid #0d0d0d;
        //         margin-left: -1px;
        //         margin-right: -1px;
        //         pointer-events: none;
        //         position: relative;
        //         word-break: normal;
        //     }

        //     .collaboration-cursor__label {
        //         border-radius: 3px 3px 3px 0;
        //         color: #0d0d0d;
        //         font-size: 18px;
        //         font-weight: 600;
        //         left: -1px;
        //         line-height: normal;
        //         padding: 0.1rem 0.3rem;
        //         position: absolute;
        //         top: -1.4em;
        //         user-select: none;
        //         white-space: nowrap;
        //     }
        // }
        // `
        // document.head.appendChild(style)
    }

    attributeChangedCallback(name: string, oldValue: string, newValue: string) {
        if (oldValue !== newValue && this.isConnected) {
            // Create a new instance with the same attributes
            const replacement = document.createElement('collaborative-editor') as CollaborativeEditor
            // Copy all current attributes to the new instance
            Array.from(this.attributes).forEach(attr => {
                replacement.setAttribute(attr.name, attr.value)
            })
            // Replace this instance with the new one
            this.parentNode?.replaceChild(replacement, this)
        }
    }

    disconnectedCallback() {
        if (this.editor) {
            this.editor.destroy()
        }
    }

    connectedCallback() {
        const editorDiv = document.createElement('div')
        editorDiv.className = 'editor'
        this.appendChild(editorDiv)

        const documentName = this.getAttribute('document-name') || 'default-doc'
        const serverUrl = this.getAttribute('server-url') || 'hail-past-brochure.glitch.me'
        const room = localStorage.getItem("room")
        const yDoc = new Y.Doc()
        if (room) {
            let obj = JSON.parse(room)

            // const provider = new WebrtcProvider(obj.name + obj.password + documentName, yDoc, { signaling: ['ws://localhost:4444'], password: obj.password })
            const provider = new IndexeddbPersistence(obj.name + obj.password + documentName, yDoc)
            const awareness = new awarenessProtocol.Awareness(yDoc)
            //@ts-ignore
            provider.awareness = awareness

            this.initializeConnections(yDoc, provider, documentName, serverUrl)

            this.initializeEditor(yDoc, provider, editorDiv)

        } else {
            location.href = '/'

        }


        // const provider = new WebrtcProvider(documentName, yDoc, { signaling: ['ws://localhost:4444'] })



    }

    initializeConnections(yDoc: Y.Doc, provider: IndexeddbPersistence, documentName: string, serverUrl: string) {
        const docSocket = new WebSocket(`wss://${serverUrl}/api/${documentName}`)

        this.setupWebSocketHandlers(docSocket, yDoc, provider)
        this.setupUpdateListeners(yDoc, provider, docSocket)
    }

    setupWebSocketHandlers(docSocket: WebSocket, yDoc: Y.Doc, provider: IndexeddbPersistence) {
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
                //@ts-ignore
                awarenessProtocol.applyAwarenessUpdate(provider.awareness, binaryEncoded, '')
            }
        }
    }

    setupUpdateListeners(yDoc: Y.Doc, provider: IndexeddbPersistence, docSocket: WebSocket) {
        yDoc.on('update', () => {
            const documentState = Y.encodeStateAsUpdate(yDoc)
            const binaryEncoded = fromUint8Array(documentState)

            if (docSocket.readyState === WebSocket.OPEN) {
                let doc = { doc: binaryEncoded }
                let json = JSON.stringify(doc)
                docSocket.send(json)
            }
        })
        //@ts-ignore
        provider.awareness.on('update', ({ added, updated, removed }) => {
            if (docSocket.readyState === WebSocket.OPEN) {
                const changedClients = added.concat(updated).concat(removed)
                //@ts-ignore
                const documentAwareness = awarenessProtocol.encodeAwarenessUpdate(provider.awareness, changedClients)
                const binaryEncoded = fromUint8Array(documentAwareness)

                let awareness = { awareness: binaryEncoded }
                let json = JSON.stringify(awareness)
                docSocket.send(json)
            }
        })
    }

    initializeEditor(yDoc: Y.Doc, provider: IndexeddbPersistence, editorDiv: HTMLElement) {
        let slides = document.querySelector('.slides-element');



        this.editor = new Editor({
            onCreate({ editor }) {
                debouncedRevealCreate(editor)
            },
            onUpdate({ editor }) {
                debouncedRevealUpdate(editor)
            },
            element: editorDiv,
            extensions: [
                StarterKit.configure({
                    history: false,
                }),

                Collaboration.configure({
                    document: provider.doc,
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


function debounce(func: Function, wait: number) {
    let timeout;

    return function executedFunction(...args: any[]) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };

        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Debounced reveal update function
const debouncedRevealUpdate = debounce((editor: any) => {
    window.Reveal.destroy();
    let slides = document.querySelector('.slides-element');

    slides!.innerHTML = /*html*/`
      <div class="reveal">
        <div class="slides">
          <section data-markdown data-visibility="uncounted"
            data-separator="<hr>"
            data-separator-vertical="--!" 
            data-separator-notes="ملاحظة:"
            data-charset="iso-8859-15">
            <textarea id="markdown-element" data-template>
              ${editor.getHTML()}
            </textarea>
          </section>
        </div> 
      </div>`;

    //@ts-ignore
    window.Reveal = new Reveal({
        scrollActivationWidth: null!,
        // rtl: true,
        respondToHashChanges: true,
        hashOneBasedIndex: false,
        showHiddenSlides: true,
        hash: true,
        embedded: true,
        center: false,
        hideCursorTime: 5000,
        transition: 'slide',
        //@ts-ignore
        slideNumber: function () {
            var idx = window.Reveal.getIndices();
            var value = ["Chapter " + idx.h];
            if (idx.h === 0) {
                value = [""]
            } else if (idx.v > 0) {
                //@ts-ignore
                value.push('Section ');
                //@ts-ignore
                value.push(idx.v);
            }
            return value;
        },
        fsfx: {
            compatibility: false,
            auto: {
                generate: true,
                color: 'var(--r-main-color)',
                oppositecolor: 'black',
                position: {
                    top: 'null',
                    bottom: '20px',
                    left: 'null',
                    right: '20px',
                }
            },
        },
        menu: {
            side: 'left',
            width: 'full',
            numbers: false,
            titleSelector: 'h1, h2, h3, h4, h5, h6',
            useTextContentForMissingTitles: true,
            hideMissingTitles: false,
            markers: true,
            custom: [
                {
                    title: 'print',
                    icon: '<i class="fas fa-file-pdf"></i>',
                    content: `    
                <a style="text-decoration: none;" href="#?print-pdf">
                  <h1>click here to print the slides to pdf</h1>
                  <i class="fas fa-file-pdf"></i>
                </a>`
                },
            ],
            themes: false,
            transitions: false,
            openButton: true,
            openSlideNumber: true,
            keyboard: true,
            sticky: false,
            autoOpen: true,
            delayInit: false,
            openOnInit: false,
            loadIcons: true
        },
        // //@ts-ignore
        plugins: [Markdown, Notes, FsFx, RevealMenu],
    });


    window.Reveal.initialize();
}, 500);

const debouncedRevealCreate = debounce((editor: any) => {
    if (window.Reveal) {
        window.Reveal.destroy();
    }
    let slides = document.querySelector('.slides-element');

    slides!.innerHTML = /*html*/` 
      <div class="reveal">
        <div class="slides">
          <section data-markdown data-visibility="uncounted"
            data-separator="<hr>"
            data-separator-vertical="--!" 
            data-separator-notes="ملاحظة:"
            data-charset="iso-8859-15">
            <textarea id="markdown-element" data-template>
              ${editor.getHTML()}
            </textarea>
          </section>
        </div> 
      </div>`;

    //@ts-ignore
    window.Reveal = new Reveal({
        scrollActivationWidth: null!,
        // rtl: true,
        respondToHashChanges: true,
        hashOneBasedIndex: false,
        showHiddenSlides: true,
        hash: true,
        embedded: true,
        center: false,
        hideCursorTime: 5000,
        transition: 'slide',
        //@ts-ignore
        slideNumber: function () {
            var idx = window.Reveal.getIndices();
            var value = ["Chapter " + idx.h];
            if (idx.h === 0) {
                value = [""]
            } else if (idx.v > 0) {
                //@ts-ignore
                value.push('Section ');
                //@ts-ignore
                value.push(idx.v);
            }
            return value;
        },
        fsfx: {
            compatibility: false,
            auto: {
                generate: true,
                color: 'var(--r-main-color)',
                oppositecolor: 'black',
                position: {
                    top: 'null',
                    bottom: '20px',
                    left: 'null',
                    right: '20px',
                }
            },
        },
        menu: {
            side: 'left',
            width: 'full',
            numbers: false,
            titleSelector: 'h1, h2, h3, h4, h5, h6',
            useTextContentForMissingTitles: true,
            hideMissingTitles: false,
            markers: true,
            custom: [
                {
                    title: 'print',
                    icon: '<i class="fas fa-file-pdf"></i>',
                    content: `    
                <a style="text-decoration: none;" href="#?print-pdf">
                  <h1>click here to print the slides to pdf</h1>
                  <i class="fas fa-file-pdf"></i>
                </a>`
                },
            ],
            themes: false,
            transitions: false,
            openButton: true,
            openSlideNumber: true,
            keyboard: true,
            sticky: false,
            autoOpen: true,
            delayInit: false,
            openOnInit: false,
            loadIcons: true
        },
        // //@ts-ignore
        plugins: [Markdown, Notes, FsFx, RevealMenu],
    });


    window.Reveal.initialize();
}, 400);

import { main } from './src/gleam_vite.gleam'
import { CollaborativeEditor } from './src/editor/index'

// document.addEventListener("DOMContentLoaded", () => {
// customElements.define('tiptap-editor', TiptapEditor);

main();
customElements.define('collaborative-editor', CollaborativeEditor)
// });










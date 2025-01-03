import { main } from './src/gleam_vite.gleam'
import { CollaborativeEditor } from './src/editor/index'
customElements.define('collaborative-editor', CollaborativeEditor)
document.addEventListener("DOMContentLoaded", () => {
    // customElements.define('tiptap-editor', TiptapEditor);

    const dispatch = main({});

});










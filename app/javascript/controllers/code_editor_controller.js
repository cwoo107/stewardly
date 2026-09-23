import { Controller } from "@hotwired/stimulus"
import { EditorView, basicSetup } from "codemirror"
import { html } from "@codemirror/lang-html"
import { json } from "@codemirror/lang-json"

// Turns a <textarea> into a CodeMirror editor (HTML/Liquid or JSON) and keeps the
// textarea in sync, so the form submits normally. Without JavaScript it stays a textarea.
export default class extends Controller {
  static values = { language: { type: String, default: "html" } }

  connect() {
    this.element.hidden = true
    this.view = new EditorView({
      doc: this.element.value,
      extensions: [ basicSetup, this.languageValue === "json" ? json() : html(), EditorView.lineWrapping,
        EditorView.updateListener.of((update) => { if (update.docChanged) this.sync() }) ],
      parent: this.element.parentElement
    })
    this.view.dom.classList.add("rounded-lg", "border", "border-gray-200", "text-sm")
  }

  disconnect() {
    this.view?.destroy()
    this.element.hidden = false
  }

  sync() {
    this.element.value = this.view.state.doc.toString()
    this.element.dispatchEvent(new Event("input", { bubbles: true }))
  }
}

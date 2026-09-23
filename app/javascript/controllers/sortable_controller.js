import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import Sortable from "sortablejs"

// Drag-and-drop lists. Each item carries data-move-url; each list may carry
// data-status (task board columns). On drop, PATCHes { position, status } and
// renders any Turbo Stream the server sends back.
export default class extends Controller {
  static values = { group: String }

  connect() {
    this.sortable = Sortable.create(this.element, {
      group: this.groupValue || undefined,
      animation: 150,
      draggable: "[data-move-url]",
      onEnd: this.moved.bind(this)
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  async moved({ item, to, newDraggableIndex }) {
    const body = new FormData()
    body.append("position", newDraggableIndex)
    if (to.dataset.status) body.append("status", to.dataset.status)

    const response = await fetch(item.dataset.moveUrl, {
      method: "PATCH",
      body,
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content
      }
    })
    const text = await response.text()
    if (response.ok && text) Turbo.renderStreamMessage(text)
  }
}

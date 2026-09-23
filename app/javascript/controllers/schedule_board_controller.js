import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import Sortable from "sortablejs"

// Drag people from the team roster into schedule slots (creates an assignment),
// or drag an assignment between slots (moves it). The server answers with Turbo
// Streams that re-render the affected cells.
export default class extends Controller {
  static targets = ["roster", "slot"]
  static values = { createUrl: String }

  rosterTargetConnected(element) {
    element.sortable = Sortable.create(element, { group: { name: "schedule", pull: "clone", put: false }, sort: false, animation: 150 })
  }

  slotTargetConnected(element) {
    element.sortable = Sortable.create(element, { group: { name: "schedule", pull: true, put: true }, sort: false, animation: 150, onAdd: this.dropped.bind(this) })
  }

  rosterTargetDisconnected(element) { element.sortable?.destroy() }
  slotTargetDisconnected(element) { element.sortable?.destroy() }

  dropped({ item, to, from }) {
    const slot = { schedulable_type: to.dataset.schedulableType, schedulable_id: to.dataset.schedulableId, position_id: to.dataset.positionId }
    if (from === this.rosterTarget) {
      item.remove() // the server renders the real card
      this.send("POST", this.createUrlValue, { ...slot, person_id: item.dataset.personId })
    } else {
      this.send("PATCH", item.dataset.assignmentUrl, slot)
    }
  }

  async send(method, url, attributes) {
    const body = new FormData()
    Object.entries(attributes).forEach(([key, value]) => body.append(`assignment[${key}]`, value))
    const response = await fetch(url, {
      method,
      body,
      headers: { Accept: "text/vnd.turbo-stream.html", "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content }
    })
    Turbo.renderStreamMessage(await response.text())
  }
}

import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Adds and removes segment conditions and keeps the live count up to date.
// Condition rows are rendered by the server; this only asks for them.
export default class extends Controller {
  static targets = ["type", "preview"]
  static values = { conditionUrl: String, previewUrl: String }

  connect() {
    this.refresh()
  }

  async add() {
    const params = new URLSearchParams({ type: this.typeTarget.value, index: Date.now() })
    const response = await fetch(`${this.conditionUrlValue}?${params}`, { headers: { Accept: "text/vnd.turbo-stream.html" } })
    Turbo.renderStreamMessage(await response.text())
    this.refresh()
  }

  remove(event) {
    event.target.closest("[data-segment-condition]").remove()
    this.refresh()
  }

  refresh() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      const params = new URLSearchParams(new FormData(this.element))
      params.delete("authenticity_token")
      params.delete("_method")
      this.previewTarget.src = `${this.previewUrlValue}?${params}`
    }, 250)
  }
}

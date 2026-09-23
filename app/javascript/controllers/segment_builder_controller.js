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
    const url = new URL(this.conditionUrlValue, window.location.href)
    url.searchParams.set("type", this.typeTarget.value)
    url.searchParams.set("index", Date.now())
    const response = await fetch(url, { headers: { Accept: "text/vnd.turbo-stream.html" } })
    Turbo.renderStreamMessage(await response.text())
    this.refresh()
  }

  remove(event) {
    event.target.closest("[data-segment-condition]").remove()
    this.refresh()
  }

  refresh() {
    if (!this.hasPreviewTarget) return
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      const url = new URL(this.previewUrlValue, window.location.href)
      new FormData(this.element).forEach((value, key) => {
        if (key !== "authenticity_token" && key !== "_method") url.searchParams.append(key, value)
      })
      this.previewTarget.src = url.toString()
    }, 250)
  }
}

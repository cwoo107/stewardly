import { Controller } from "@hotwired/stimulus"

// Remembers which sidebar sections a person has opened (per browser). The section
// holding the current page is always open; the server marks it data-active.
const STORAGE_KEY = "stewardly:nav-sections"

export default class extends Controller {
  static targets = ["section"]

  connect() {
    const saved = this.read()
    this.sectionTargets.forEach(section => {
      if (section.dataset.active === "true") return
      if (section.dataset.key in saved) section.open = saved[section.dataset.key]
    })
    this.toggled = this.save.bind(this)
    this.sectionTargets.forEach(section => section.addEventListener("toggle", this.toggled))
  }

  disconnect() {
    this.sectionTargets.forEach(section => section.removeEventListener("toggle", this.toggled))
  }

  save(event) {
    const saved = this.read()
    saved[event.target.dataset.key] = event.target.open
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(saved)) } catch { /* private mode: just don't remember */ }
  }

  read() {
    try { return JSON.parse(localStorage.getItem(STORAGE_KEY)) || {} } catch { return {} }
  }
}

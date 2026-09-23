import { Controller } from "@hotwired/stimulus"

// Reloads its Turbo Frame every few seconds (e.g. while the report assistant is answering).
// The server stops the polling by rendering the frame without this controller.
export default class extends Controller {
  static values = { interval: { type: Number, default: 2000 } }

  connect() {
    this.timer = setTimeout(() => this.element.closest("turbo-frame")?.reload(), this.intervalValue)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}

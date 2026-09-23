import { Controller } from "@hotwired/stimulus"

// Submits its form when a field changes (e.g. picking a trigger type reloads its settings).
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}

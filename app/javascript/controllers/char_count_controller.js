import { Controller } from "@hotwired/stimulus"

// Live character counts against each network's limit.
// <div data-controller="char-count"><textarea data-char-count-target="input">
// <span data-char-count-target="count" data-limit="2200"></span>
export default class extends Controller {
  static targets = ["input", "count"]

  connect() { this.update() }

  update() {
    const length = this.inputTarget.value.length
    this.countTargets.forEach((count) => {
      const limit = Number(count.dataset.limit)
      count.textContent = `${length.toLocaleString()} / ${limit.toLocaleString()}`
      count.classList.toggle("text-rose-700", length > limit)
    })
  }
}

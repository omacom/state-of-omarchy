import { Controller } from "@hotwired/stimulus"

// Code entry: uppercases as you type, enables the button at full length and submits
// automatically when a complete code is typed or pasted.
export default class extends Controller {
  static targets = ["input", "submit"]
  static values = { length: { type: Number, default: 6 } }

  connect() {
    this.changed()
  }

  changed() {
    const cleaned = this.inputTarget.value.toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, this.lengthValue)
    if (cleaned !== this.inputTarget.value) this.inputTarget.value = cleaned
    const complete = cleaned.length === this.lengthValue
    this.submitTarget.disabled = !complete
    if (complete && !this.submitted) {
      this.submitted = true
      this.element.requestSubmit()
    }
  }

  paste(event) {
    const text = (event.clipboardData || window.clipboardData)?.getData("text")
    if (!text) return
    event.preventDefault()
    this.inputTarget.value = text
    this.changed()
  }
}

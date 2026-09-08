import { Controller } from "@hotwired/stimulus"

// Single and multiple choice: shows the "Other" write-in when picked, enforces the
// selection limit (extra boxes disable at the cap) and exclusive options ("None"
// clears everything else, and vice versa).
export default class extends Controller {
  static targets = ["other", "count"]
  static values = { otherId: { type: String, default: "other" }, limit: Number, exclusive: { type: Array, default: [] } }

  connect() {
    this.sync()
  }

  changed(event) {
    const input = event.target
    if (input.type === "checkbox" && input.checked) {
      const boxes = this.checkboxes
      if (this.exclusiveValue.includes(input.value)) {
        boxes.forEach((box) => { if (box !== input) box.checked = false })
      } else {
        boxes.forEach((box) => { if (this.exclusiveValue.includes(box.value)) box.checked = false })
      }
    }
    this.sync()
  }

  sync() {
    const selected = this.inputs.filter((i) => i.checked).map((i) => i.value)
    if (this.hasOtherTarget) this.otherTarget.hidden = !selected.includes(this.otherIdValue)
    if (this.hasLimitValue && this.limitValue > 0) {
      const atLimit = selected.length >= this.limitValue
      this.checkboxes.forEach((box) => { box.disabled = atLimit && !box.checked })
    }
    if (this.hasCountTarget) this.countTarget.textContent = selected.length
  }

  get inputs() {
    return Array.from(this.element.querySelectorAll("input[type=radio], input[type=checkbox]"))
  }

  get checkboxes() {
    return Array.from(this.element.querySelectorAll("input[type=checkbox]"))
  }
}

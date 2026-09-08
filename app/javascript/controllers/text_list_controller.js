import { Controller } from "@hotwired/stimulus"

// Free-text list with add/remove rows, capped at the question's limit.
export default class extends Controller {
  static targets = ["items", "item", "template", "add"]
  static values = { max: Number, limit: Number, prompt: String, placeholder: String }

  connect() {
    this.renumber()
  }

  add() {
    if (this.itemTargets.length >= this.maxValue) return
    this.itemsTarget.appendChild(this.templateTarget.content.cloneNode(true))
    this.renumber()
    this.itemTargets.at(-1)?.querySelector("input")?.focus()
  }

  remove(event) {
    event.target.closest("[data-text-list-target='item']")?.remove()
    this.renumber()
    this.element.dispatchEvent(new Event("change", { bubbles: true }))
  }

  renumber() {
    this.itemTargets.forEach((row, i) => {
      const input = row.querySelector("input")
      input.placeholder = this.placeholderValue || `Entry ${i + 1}`
      input.setAttribute("aria-label", `${this.promptValue} ${i + 1}`)
      row.querySelector("button")?.setAttribute("aria-label", `Remove entry ${i + 1}`)
    })
    const count = this.itemTargets.length
    this.addTarget.hidden = count >= this.maxValue
    this.addTarget.textContent = this.hasLimitValue && this.limitValue > 0 ? `Add (${count}/${this.limitValue})` : "Add"
  }
}

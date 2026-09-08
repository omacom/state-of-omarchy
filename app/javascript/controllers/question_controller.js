import { Controller } from "@hotwired/stimulus"

// Per-question card state: flips data-answered as the user interacts (drives the
// border/check styling) and clears a stale inline error on the first edit.
export default class extends Controller {
  changed() {
    this.element.dataset.answered = String(answerIds(this.element).length > 0)
    const error = this.element.querySelector(".q-error")
    if (error) error.textContent = ""
  }
}

// Every answer-bearing input inside a card, as comparable id/text strings. Shared with
// the visibility controller for showIf evaluation. Generic by input kind, never by question id.
export function answerIds(card) {
  const ids = []
  for (const el of card.querySelectorAll("input, select, textarea")) {
    if (!el.name || /\[type\]$/.test(el.name) || /\[other\]$/.test(el.name)) continue
    if (el.type === "radio" || el.type === "checkbox") {
      if (el.checked) ids.push(el.value)
    } else if (el.type === "range") {
      continue
    } else if (el.value && el.value.trim() !== "") {
      ids.push(el.value.trim())
    }
  }
  return ids
}

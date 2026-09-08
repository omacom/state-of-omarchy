import { Controller } from "@hotwired/stimulus"
import { answerIds } from "controllers/question_controller"

// Generic showIf: a card with data-show-if-* is shown or hidden from the answer of its
// target card whenever that target lives in the same section. Targets in other
// sections are resolved server-side when the section renders, and the server always
// drops answers to questions that are hidden — this only keeps the page in sync.
export default class extends Controller {
  connect() {
    this.update()
  }

  update() {
    for (const card of this.element.querySelectorAll("[data-show-if-question]")) {
      const target = this.element.querySelector(`[data-question-id="${CSS.escape(card.dataset.showIfQuestion)}"]`)
      if (!target) continue
      const ids = target.hidden ? [] : answerIds(target)
      const values = JSON.parse(card.dataset.showIfValues || "[]")
      let visible
      if (ids.length === 0) visible = false
      else if (card.dataset.showIfOp === "eq") visible = ids.length === 1 && values.includes(ids[0])
      else visible = ids.some((id) => values.includes(id))
      if (card.hidden === visible) card.hidden = !visible
    }
  }
}

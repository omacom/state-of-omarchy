import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Debounced autosave for the survey section form. Every change PATCHes the whole
// section; the server answers with a Turbo Stream that refreshes progress, counts,
// the stepper and per-question inline errors. Nav buttons submit the same form the
// normal way, so nothing here is required for the survey to work.
export default class extends Controller {
  static targets = ["status"]
  static values = { delay: { type: Number, default: 800 } }

  schedule() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.save(), this.delayValue)
  }

  cancel() {
    clearTimeout(this.timer)
  }

  async save() {
    if (this.saving) {
      this.queued = true
      return
    }
    this.saving = true
    this.setState("saving")
    try {
      const body = new FormData(this.element)
      body.set("commit", "autosave")
      const response = await fetch(this.element.action, {
        method: "POST",
        body,
        credentials: "same-origin",
        headers: { Accept: "text/vnd.turbo-stream.html", "X-Requested-With": "XMLHttpRequest" }
      })
      const html = await response.text()
      if ((response.headers.get("content-type") || "").includes("turbo-stream")) {
        Turbo.renderStreamMessage(html)
      }
      this.setState(response.ok ? "saved" : "error")
    } catch {
      this.setState("error")
    } finally {
      this.saving = false
      if (this.queued) {
        this.queued = false
        this.save()
      }
    }
  }

  setState(state) {
    if (this.hasStatusTarget) this.statusTarget.dataset.state = state
  }
}

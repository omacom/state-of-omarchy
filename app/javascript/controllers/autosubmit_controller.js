import { Controller } from "@hotwired/stimulus"

// Submits the form as soon as it connects (used by the emailed magic link landing page,
// so a real browser signs in instantly while a link prefetch without JS does not).
export default class extends Controller {
  connect() {
    requestAnimationFrame(() => this.element.requestSubmit())
  }
}

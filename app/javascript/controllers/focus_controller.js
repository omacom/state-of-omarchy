import { Controller } from "@hotwired/stimulus"

// Moves keyboard/screen-reader focus to the section heading whenever a section renders,
// so users restart from a known point instead of a dead button after Next/Back.
export default class extends Controller {
  connect() {
    this.element.focus({ preventScroll: true })
  }
}

import { Controller } from "@hotwired/stimulus"

// Keeps the active step pill in view on load (the nav can overflow on mobile).
export default class extends Controller {
  connect() {
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.element.querySelector("[aria-current='step']")?.scrollIntoView({
      behavior: reduced ? "auto" : "smooth", inline: "center", block: "nearest"
    })
  }
}

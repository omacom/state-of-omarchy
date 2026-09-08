import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "count"]

  update() {
    if (this.hasCountTarget) this.countTarget.textContent = this.inputTarget.value.length
  }
}

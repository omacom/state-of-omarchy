import { Controller } from "@hotwired/stimulus"

// Disables the "send again" button for a few seconds after arriving on the page.
export default class extends Controller {
  static targets = ["button"]
  static values = { seconds: { type: Number, default: 20 } }

  connect() {
    this.label = this.buttonTarget.textContent
    this.remaining = this.secondsValue
    this.tick()
    this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  tick() {
    if (this.remaining > 0) {
      this.buttonTarget.disabled = true
      this.buttonTarget.textContent = `Send again in ${this.remaining}s`
      this.remaining -= 1
    } else {
      clearInterval(this.timer)
      this.buttonTarget.disabled = false
      this.buttonTarget.textContent = this.label
    }
  }
}

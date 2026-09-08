import { Controller } from "@hotwired/stimulus"

// Range slider with a floating value bubble. The hidden [value] field is what gets
// saved, and it stays empty until the user actually moves the slider.
export default class extends Controller {
  static targets = ["range", "value", "bubble", "bubbleText", "ticks", "band"]
  static values = { min: Number, max: Number, nps: Boolean }

  changed() {
    const current = Number(this.rangeTarget.value)
    this.valueTarget.value = current
    const pct = this.maxValue > this.minValue ? ((current - this.minValue) / (this.maxValue - this.minValue)) * 100 : 0
    this.rangeTarget.style.setProperty("--fill", `${pct}%`)
    this.rangeTarget.setAttribute("aria-valuetext", String(current))
    this.bubbleTarget.style.left = `${pct}%`
    this.bubbleTextTarget.textContent = current
    this.bubbleTarget.hidden = false
    for (const tick of this.ticksTarget.children) {
      tick.className = Number(tick.dataset.tick) === current ? "sr-only" : "size-1 rounded-full bg-background/70"
    }
    if (this.hasBandTarget) {
      this.bandTarget.textContent = current <= 6 ? "Detractor" : current <= 8 ? "Passive" : "Promoter"
    }
  }
}

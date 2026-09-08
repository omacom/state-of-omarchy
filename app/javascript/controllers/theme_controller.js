import { Controller } from "@hotwired/stimulus"

// Light/dark toggle. The saved choice is applied before first paint by the inline
// script in the layout <head>; this only flips and persists it.
export default class extends Controller {
  toggle() {
    const dark = !document.documentElement.classList.contains("dark")
    document.documentElement.classList.toggle("dark", dark)
    document.documentElement.style.colorScheme = dark ? "dark" : "light"
    try { localStorage.setItem("theme", dark ? "dark" : "light") } catch {}
  }
}

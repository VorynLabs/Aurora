import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "menu"]

  connect() {
    this.closeOnOutsideClick = this.closeOnOutsideClick.bind(this)
    document.addEventListener("click", this.closeOnOutsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnOutsideClick)
  }

  toggle() {
    this.open ? this.hide() : this.show()
  }

  show() {
    this.menuTarget.hidden = false
    this.buttonTarget.setAttribute("aria-expanded", "true")
    this.firstItem?.focus()
  }

  hide() {
    this.menuTarget.hidden = true
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }

  closeOnEscape() {
    if (!this.open) return

    this.hide()
    this.buttonTarget.focus()
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) this.hide()
  }

  get open() {
    return !this.menuTarget.hidden
  }

  get firstItem() {
    return this.menuTarget.querySelector("a, button")
  }
}

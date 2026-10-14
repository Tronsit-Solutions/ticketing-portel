import { Controller } from "@hotwired/stimulus"

// Slides the layout sidebar in and out as a drawer on small screens.
// Lives on <body>; the open state is just a class the CSS keys off.
export default class extends Controller {
  static targets = ["toggle"]

  toggle() {
    this.#setOpen(!this.element.classList.contains("sidebar-open"))
  }

  close() {
    this.#setOpen(false)
  }

  #setOpen(open) {
    this.element.classList.toggle("sidebar-open", open)
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-expanded", open)
  }
}

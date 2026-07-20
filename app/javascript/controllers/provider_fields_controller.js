import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "fields"]

  connect() {
    this.toggle()
  }

  toggle() {
    const isProvider = this.selectTarget.value === "true"
    this.fieldsTarget.hidden = !isProvider
  }
}

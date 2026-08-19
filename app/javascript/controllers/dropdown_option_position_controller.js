import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["category", "position"]
  static values = { url: String }

  async update() {
    const category = this.categoryTarget.value
    const response = await fetch(`${this.urlValue}?category=${encodeURIComponent(category)}`, {
      headers: { Accept: "application/json" },
      credentials: "same-origin"
    })
    if (!response.ok) return

    const data = await response.json()
    if (data.position) this.positionTarget.value = data.position
  }
}

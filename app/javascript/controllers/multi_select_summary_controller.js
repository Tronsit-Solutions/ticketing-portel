import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "pillBox", "summary"]

  connect() {
    this.render()
  }

  render() {
    const selectedCheckboxes = this.checkboxTargets.filter((checkbox) => checkbox.checked)
    const selectedLabels = selectedCheckboxes.map((checkbox) => checkbox.value)

    this.pillBoxTarget.innerHTML = ""
    selectedCheckboxes.forEach((checkbox) => {
      const pill = document.createElement("span")
      pill.className = "team-select-pill"

      const label = document.createElement("span")
      label.textContent = checkbox.value
      pill.appendChild(label)

      const removeButton = document.createElement("button")
      removeButton.type = "button"
      removeButton.className = "team-select-pill-remove"
      removeButton.setAttribute("aria-label", `Remove ${checkbox.value}`)
      removeButton.textContent = "×"
      removeButton.addEventListener("click", (event) => {
        event.stopPropagation()
        checkbox.checked = false
        this.render()
      })
      pill.appendChild(removeButton)

      this.pillBoxTarget.appendChild(pill)
    })

    this.summaryTarget.textContent = selectedLabels.join(", ")
  }
}

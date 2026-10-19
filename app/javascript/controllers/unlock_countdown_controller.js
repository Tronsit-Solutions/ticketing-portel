import { Controller } from "@hotwired/stimulus"

// Counts down to when a locked account may sign in again. The server sends
// the seconds remaining rather than a timestamp, so a wrong clock on the
// viewer's machine can't skew it.
export default class extends Controller {
  static targets = ["message"]
  static values = { seconds: Number }

  connect() {
    this.endsAt = Date.now() + this.secondsValue * 1000
    this.tick()
    this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  tick() {
    const remaining = Math.max(0, Math.ceil((this.endsAt - Date.now()) / 1000))

    if (remaining === 0) {
      clearInterval(this.timer)
      this.messageTarget.textContent = "Your account is unlocked. You can sign in again now."
      this.element.classList.replace("alert-warning", "alert-success")
      return
    }

    const minutes = Math.floor(remaining / 60)
    const seconds = String(remaining % 60).padStart(2, "0")
    this.messageTarget.textContent = `Try again in ${minutes}:${seconds}.`
  }
}

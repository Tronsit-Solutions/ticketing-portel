import { Controller } from "@hotwired/stimulus"

// Keeps a message list scrolled to the newest message, including ones that
// arrive over Turbo Streams, and drops the "No messages yet" placeholder
// once the first message appears.
export default class extends Controller {
  connect() {
    this.scrollToBottom()
    this.observer = new MutationObserver(() => {
      this.element.querySelector(".no-messages-placeholder")?.remove()
      this.scrollToBottom()
    })
    this.observer.observe(this.element, { childList: true })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  scrollToBottom() {
    this.element.scrollTop = this.element.scrollHeight
  }
}

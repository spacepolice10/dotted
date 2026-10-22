import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.abortController = new AbortController()
    const { signal } = this.abortController

    document.addEventListener("keydown", this.onKeydown.bind(this), { signal })
    document.addEventListener("keyup", this.onKeyup.bind(this), { signal })
    document.addEventListener("focusin", this.onFocusin.bind(this), { signal })
    document.addEventListener("visibilitychange", this.onVisibilityChange.bind(this), { signal })
    document.addEventListener("turbo:before-visit", this.hide.bind(this), { signal })
  }

  disconnect() {
    this.abortController.abort()
    this.hide()
  }

  onKeydown(event) {
    if (this.#shouldIgnore(event)) {
      this.hide()
      return
    }

    if (event.shiftKey) this.show()
  }

  onKeyup(event) {
    if (!event.shiftKey) this.hide()
  }

  onFocusin(event) {
    if (this.#shouldIgnore(event)) this.hide()
  }

  onVisibilityChange() {
    if (document.hidden) this.hide()
  }

  show() {
    this.element.classList.add("show-hotkey-hint")
  }

  hide() {
    this.element.classList.remove("show-hotkey-hint")
  }

  #shouldIgnore(event) {
    return event.defaultPrevented ||
      event.target.closest("input, textarea, [contenteditable], lexxy-editor, .lexxy-editor__content")
  }
}

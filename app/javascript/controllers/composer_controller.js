import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"
import { clientId, failPending, insertPending, removePending } from "helpers/composer_helpers"

const APPEND_TO = "timeline_section_current_date"

export default class extends Controller {
  static targets = ["form", "editor", "pendingTextTemplate"]
  #submitting = false

  async submit(event) {
    event.preventDefault()
    if (this.#submitting) return
    this.#submitting = true
    try {
      if (this.editorTarget.isBlank) return

      const form = this.formTarget
      const action = form.action
      const container = document.getElementById(APPEND_TO)
      if (!container) return

      const body = new FormData(form)
      body.delete("bullet[file]")
      const id = clientId()

      const preview = this.editorTarget.value
      // Reset Lexxy's content and selection before the one pending-row scroll.
      this.restore()
      this.#insertTextPending(id, container, preview)
      body.set("bullet[client_id]", id)

      try {
        const response = await post(action, { body, responseKind: "turbo-stream" })
        if (!response.ok) removePending(id)
      } catch {
        failPending(id)
      }
    } finally {
      this.#submitting = false
    }
  }

  submitByKeyboard(event) {
    if (!event.composedPath().includes(this.editorTarget)) return

    event.stopPropagation()
    event.stopImmediatePropagation()
    const metaReturn = event.key == "Enter" && (event.metaKey || event.ctrlKey)
    const justReturn = event.keyCode == 13 && !event.shiftKey && !event.isComposing
    if (!this.#coarsePointer && (metaReturn || justReturn)) {
      event.preventDefault()
      this.submit(event)
    }
  }

  restore() {
    this.editorTarget.value = ""
    this.editorTarget.focus()
  }

  #insertTextPending(id, container, preview) {
    insertPending(this.pendingTextTemplateTarget, container, id, (node) => {
      node.querySelectorAll("[data-pending-body]").forEach((el) => {
        // Lexxy's serialized value is sanitized HTML, as submitted in the form.
        // Use the saved row's rich-text layout instead of a clamped text preview.
        el.innerHTML = preview
      })
    })
  }

  get #coarsePointer() {
    return "ontouchstart" in window || navigator.maxTouchPoints > 0 || navigator.msMaxTouchPoints > 0
  }
}

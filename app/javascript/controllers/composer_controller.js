import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"
import { clientId, failPending, insertPending, removePending } from "helpers/composer_helpers"

const APPEND_TO = "timeline_section_current_date"

export default class extends Controller {
  static targets = ["form", "editor", "pendingTextTemplate"]

  async submit(event) {
    event.preventDefault()
    if (this.editorTarget.isBlank) return

    const form = this.formTarget
    const action = form.action
    const container = document.getElementById(APPEND_TO)
    if (!container) return

    const body = new FormData(form)
    body.delete("bullet[file]")
    const id = clientId()

    this.#insertTextPending(id, container)
    body.set("bullet[client_id]", id)

    this.restore()

    try {
      const response = await post(action, { body, responseKind: "turbo-stream" })
      if (!response.ok) removePending(id)
    } catch {
      failPending(id)
    }
  }

  submitByKeyboard(event) {
    event.stopPropagation()
    event.stopImmediatePropagation()
    const metaReturn = event.key == "Enter" && (event.metaKey || event.ctrlKey)
    const justReturn = event.keyCode == 13 && !event.shiftKey && !event.isComposing
    if (metaReturn || justReturn) {
      event.preventDefault()
      this.submit(event)
    }
  }

  restore() {
    this.editorTarget.value = ""
    this.editorTarget.focus()
  }

  #insertTextPending(id, container) {
    const preview = this.element.querySelector(".lexxy-editor__content")?.innerText?.trim() || ""
    insertPending(this.pendingTextTemplateTarget, container, id, (node) => {
      node.querySelectorAll("[data-pending-body]").forEach((el) => {
        el.textContent = preview
      })
    })
  }

  get #coarsePointer() {
    return "ontouchstart" in window || navigator.maxTouchPoints > 0 || navigator.msMaxTouchPoints > 0
  }
}

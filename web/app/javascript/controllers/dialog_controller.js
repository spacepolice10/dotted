import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    if (this.element !== document.body) return

    this.beforeRenderHandler = (event) => {
      event.detail.newBody
        .querySelectorAll("dialog[open]")
        .forEach((dialog) => dialog.close())
    }

    this.beforeMorphAttributeHandler = (event) => {
      const { target, detail: { attributeName, mutationType } } = event

      if (target instanceof HTMLDialogElement &&
          attributeName === "open" &&
          mutationType === "remove") {
        event.preventDefault()
        target.close()
      }
    }

    document.addEventListener("turbo:before-render", this.beforeRenderHandler)
    document.addEventListener("turbo:before-morph-attribute", this.beforeMorphAttributeHandler)
  }

  disconnect() {
    if (this.beforeRenderHandler) {
      document.removeEventListener("turbo:before-render", this.beforeRenderHandler)
    }
    if (this.beforeMorphAttributeHandler) {
      document.removeEventListener("turbo:before-morph-attribute", this.beforeMorphAttributeHandler)
    }
  }

  show() {
    this.#ensureOpen(this.dialog)
  }

  close() {
    this.dialog.close()
  }

  backdropHide(event) {
    if ("closedBy" in HTMLDialogElement.prototype) return
    if (event.target === this.dialog) this.close()
  }

  submitSuccess(ev) {
    if (ev.detail.success) this.close()
  }

  get dialog() {
    if (this.element instanceof HTMLDialogElement) return this.element

    return this.hasDialogTarget ? this.dialogTarget : this.element
  }

  #ensureOpen(dialog) {
    if (dialog.open) return

    try {
      dialog.showModal()
    } catch (error) {
      if (error.name != "InvalidStateError") throw error

      dialog.close()
      dialog.showModal()
    }
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["textfield"]

  open(event) {
    if (event.defaultPrevented || event.isComposing || event.keyCode == 229 || event.repeat) return
    if (event.ctrlKey || event.metaKey || event.altKey) return
    if (!/^\p{L}$/u.test(event.key)) return
    if (event.target.closest?.("input, textarea, select, [contenteditable], [role=textbox], lexxy-editor, .search--textform")) return
    if (document.querySelector("dialog[open], .bullet-menu:not([hidden])")) return

    event.preventDefault()
    this.textfieldTarget.value = event.key
    this.element.showModal()
    this.textfieldTarget.focus({ preventScroll: true })
    this.textfieldTarget.setSelectionRange(event.key.length, event.key.length)
    this.textfieldTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }
}

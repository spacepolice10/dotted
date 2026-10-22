import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { nextUrl: String }

  openPicker(event) {
    const { dialog: dialogId, frame: frameId, url } = event.params
    const dialog = document.getElementById(dialogId)
    const frame = document.getElementById(frameId)
    if (!dialog || !frame || !url) return

    frame.src = url
    if (!dialog.open) dialog.showModal()
  }

  advance(event) {
    if (!event.detail.success) return
    if (!event.target.closest("#postpone_dialog, #collects_dialog")) return

    Turbo.visit(this.nextUrlValue, { action: "replace" })
  }
}

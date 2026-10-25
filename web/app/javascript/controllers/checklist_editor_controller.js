import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["items", "template", "row", "position", "addButton"]

  connect() {
    this.nextIndex = Date.now()
  }

  add(event) {
    const fragment = this.templateTarget.content.cloneNode(true)
    const row = fragment.querySelector("[data-checklist-editor-target~='row']")
    const index = String(this.nextIndex++)
    row.querySelectorAll("[name], [id], [for]").forEach((element) => {
      for (const attribute of ["name", "id", "for"]) {
        if (element.hasAttribute(attribute)) {
          element.setAttribute(attribute, element.getAttribute(attribute).replaceAll("NEW_ITEM", index))
        }
      }
    })
    const currentRow = event?.target.closest("[data-checklist-editor-target~='row']")
    if (currentRow) {
      currentRow.after(fragment)
    } else {
      this.itemsTarget.insertBefore(fragment, this.addButtonTarget)
    }
    row.querySelector("input[type='text']").focus()
    this.reindex()
  }

  remove(event) {
    const row = event.currentTarget.closest("[data-checklist-editor-target~='row']")
    if (row.dataset.persisted === "true") {
      row.querySelector("[data-checklist-editor-target~='destroy']").value = "1"
      row.querySelector("input[type='text']").disabled = true
      row.hidden = true
    } else {
      row.remove()
    }
    this.reindex()
  }

  addOnEnter(event) {
    if (!event.target.matches("input[type='text']") || event.isComposing) return
    event.preventDefault()
    this.add(event)
  }

  reindex() {
    this.rowTargets.filter((row) => !row.hidden).forEach((row, index) => {
      row.querySelector("[data-checklist-editor-target~='position']").value = index
    })
  }
}

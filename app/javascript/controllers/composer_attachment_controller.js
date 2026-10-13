import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"
import { post } from "@rails/request.js"
import { clientId, failPending, insertPending, notify, removePending } from "helpers/composer_helpers"

const MAXIMUM_SIZE = 5 * 1024 * 1024
const APPEND_TO = "timeline_section_current_date"

export default class extends Controller {
  static targets = ["file", "pendingFileTemplate"]

  choose(event) {
    event.preventDefault()
    this.fileTarget.click()
  }

  async attach() {
    const file = this.fileTarget.files[0]
    if (!file) return

    const container = document.getElementById(APPEND_TO)
    if (!container) return

    const form = this.fileTarget.form
    const action = form.action
    const uploadLink =
      this.fileTarget.dataset.directUploadUrl ||
      "/rails/active_storage/direct_uploads"
    const body = new FormData(form)
    body.delete("bullet[body]")
    this.fileTarget.value = ""

    if (file.size > MAXIMUM_SIZE) {
      notify("File is too large (maximum is 5 MB)")
      return
    }

    const id = clientId()
    this.#insertFilePending(id, file, container)
    body.set("bullet[client_id]", id)

    try {
      const signedId = await this.#directUpload(file, uploadLink)
      body.set("bullet[file]", signedId)

      const response = await post(action, { body, responseKind: "turbo-stream" })
      if (!response.ok) removePending(id)
    } catch {
      failPending(id, "Upload failed")
    }
  }

  #directUpload(file, uploadLink) {
    return new Promise((resolve, reject) => {
      new DirectUpload(file, uploadLink).create((error, blob) => {
        if (error) reject(error)
        else resolve(blob.signed_id)
      })
    })
  }

  #insertFilePending(id, file, container) {
    insertPending(this.pendingFileTemplateTarget, container, id, (node) => {
      node.querySelectorAll("[data-pending-filename]").forEach((el) => {
        el.textContent = file.name
      })
      if (!file.type.startsWith("image/")) return

      const img = node.querySelector("[data-pending-image]")
      if (!img) return

      const url = URL.createObjectURL(file)
      img.src = url
      img.alt = file.name
      img.hidden = false
      node.querySelectorAll(".attachment--file").forEach((el) => {
        el.hidden = true
      })
      img.onload = () => URL.revokeObjectURL(url)
      img.onerror = () => {
        URL.revokeObjectURL(url)
        img.hidden = true
        node.querySelectorAll(".attachment--file").forEach((el) => {
          el.hidden = false
        })
      }

      // Reserve the final box upfront: same ratio the server render uses,
      // so submit → upload → replace swaps pixels, not layout.
      if (globalThis.createImageBitmap) {
        createImageBitmap(file).then((bitmap) => {
          if (bitmap.width && bitmap.height) {
            img.style.aspectRatio = `${bitmap.width} / ${bitmap.height}`
          }
          bitmap.close?.()
        }).catch(() => {})
      }
    })
  }
}

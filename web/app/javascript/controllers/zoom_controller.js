import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  zoom(event) {
    const imgSrc = event.target.src
    if (!imgSrc) return

    Turbo.visit(imgSrc, { action: "advance" })
  }
}

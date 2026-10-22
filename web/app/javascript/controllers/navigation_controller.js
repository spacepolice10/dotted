import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  back(event) {
    if (event.ctrlKey || event.metaKey || event.shiftKey) return

    if (window.history.length > 1) {
      event.preventDefault()
      window.history.back()
    }
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { length: Number }

  submit(event) {
    if (this.lengthValue > 0 && event.target.value.length < this.lengthValue) return

    this.element.requestSubmit()
  }
}

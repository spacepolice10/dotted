import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"

export default class extends Controller {
  static values = { url: String }

  changeAppearance(event) {
    const appearance = event.target.value
    document.documentElement.dataset.appearance = appearance

    post(this.urlValue, { body: { appearance } })
  }
}

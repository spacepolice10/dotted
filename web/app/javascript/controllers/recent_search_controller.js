import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"

// Records a recent search when a search result is clicked. Fire-and-forget:
// keepalive lets the beacon survive the navigation it triggers. Prefetch
// never clicks, so hovers stay unrecorded.
export default class extends Controller {
  static values = {
    searchableType: String,
    searchableId: String,
    url: String,
  }

  record() {
    post(this.urlValue, {
      body: {
        searchable_type: this.searchableTypeValue,
        searchable_id: this.searchableIdValue,
      },
      keepalive: true,
      responseKind: "json",
    })
  }
}

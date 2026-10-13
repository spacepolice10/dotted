import { Controller } from "@hotwired/stimulus"
import { debounce } from "helpers/debounce"

const DEFAULT_DEBOUNCE_MS = 80

export default class extends Controller {
  static targets = ["input", "section"]
  static values = {
    path: String,
    debounceMs: { type: Number, default: DEFAULT_DEBOUNCE_MS },
  }

  #debouncedReplace = null

  connect() {
    this.#debouncedReplace = debounce(() => this.#replaceSection(), this.debounceMsValue)
  }

  input() {
    this.#debouncedReplace()
  }

  cleanup() {
    this.inputTarget.value = ""
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.inputTarget.focus()
  }

  // The frame wraps only the results list, so replacing its src never re-renders
  // the input and the caret survives typing.
  #replaceSection() {
    this.#load(this.inputTarget.value.trim() ? { q: this.inputTarget.value.trim() } : {})
  }

  #load(params) {
    if (!this.hasSectionTarget) return

    const url = new URL(this.pathValue || "/search/results", window.location.origin)
    Object.entries(params).forEach(([key, value]) => url.searchParams.set(key, value))

    this.sectionTarget.src = `${url.pathname}${url.search}`
  }
}

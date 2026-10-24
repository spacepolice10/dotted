import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["actions", "next", "prev"]

  connect() {
    this.sync()
  }

  disconnect() {
    if (this.syncFrame) cancelAnimationFrame(this.syncFrame)
  }

  afterStream() {
    if (this.syncFrame) cancelAnimationFrame(this.syncFrame)
    this.syncFrame = requestAnimationFrame(() => {
      this.syncFrame = null
      this.sync()
    })
  }

  sync() {
    const selected = this.#selected()
    const items = selected.map((checkbox) => checkbox.closest(".collection--item"))
    const board = items[0]?.closest(".collection-board")
    const sameLane = board && items.every((item) => item && item.closest(".collection-board") === board && item.dataset.lane === items[0].dataset.lane)
    const lane = sameLane ? items[0].dataset.lane : null
    this.nextTarget.hidden = lane !== "unsorted"
    this.prevTarget.hidden = lane !== "parked"
    this.actionsTarget.hidden = !lane
  }

  move(event) {
    const selected = this.#selected()
    const board = selected[0]?.closest(".collection-board")
    if (!board) return

    board.dispatchEvent(new CustomEvent("collection-board:move", {
      detail: { ids: selected.map((checkbox) => checkbox.value), lane: event.currentTarget.dataset.lane },
    }))

    selected.forEach((checkbox) => checkbox.click())
    this.sync()
  }

  #selected() {
    return [...document.querySelectorAll(".collection-board .collection--item input[data-bullet-menu-target~='checkbox']:checked")]
  }
}

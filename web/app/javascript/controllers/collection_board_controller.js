import { Controller } from "@hotwired/stimulus"
import { notify } from "helpers/composer_helpers"

export default class extends Controller {
  static targets = ["lane", "item"]

  start(event) {
    const item = event.currentTarget
    this.draggedId = item.dataset.bulletId
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.draggedId)
    item.classList.add("is-dragging")
  }

  end() {
    this.draggedId = null
    this.#clearDrop()
    this.#clearDrag()
  }

  over(event) {
    if (!this.draggedId) return
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    this.#markDrop(event.currentTarget, event.clientY)
  }

  leave(event) {
    if (event.currentTarget.contains(event.relatedTarget)) return
    this.#clearDrop()
  }

  drop(event) {
    if (!this.draggedId) return
    event.preventDefault()
    const item = this.itemTargets.find((candidate) => candidate.dataset.bulletId == this.draggedId)
    const lane = event.currentTarget
    const beforeId = this.#beforeId(lane, event.clientY)
    this.#clearDrop()
    this.draggedId = null
    this.#clearDrag()
    this.#submit(item, lane.dataset.lane, beforeId)
  }

  #markDrop(lane, y) {
    this.#clearDrop()
    lane.classList.add("is-drop-target")
    const beforeId = this.#beforeId(lane, y)
    if (beforeId) {
      this.itemTargets.find((item) => item.dataset.bulletId == beforeId)?.classList.add("is-drop-before")
    }
  }

  #beforeId(lane, y) {
    if (lane.dataset.lane != "parked") return null
    const items = this.itemTargets.filter((item) => item.closest(".collection--lane") == lane && item.dataset.bulletId != this.draggedId)
    return items.find((item) => y < item.getBoundingClientRect().top + item.getBoundingClientRect().height / 2)?.dataset.bulletId
  }

  #clearDrop() {
    this.laneTargets.forEach((lane) => lane.classList.remove("is-drop-target"))
    this.itemTargets.forEach((item) => item.classList.remove("is-drop-before"))
  }

  #clearDrag() {
    this.itemTargets.forEach((item) => item.classList.remove("is-dragging"))
  }

  moveSelected(event) {
    const { ids, lane } = event.detail
    if (!ids?.length) return
    this.#request(this.element.dataset.bulkMoveUrl, new URLSearchParams({ bullet_ids: ids.join(","), lane }))
  }

  async #submit(item, lane, beforeId) {
    if (!item) return
    const body = new URLSearchParams({ lane })
    if (beforeId) body.set("before_id", beforeId)

    this.#request(item.dataset.moveUrl, body)
  }

  async #request(url, body) {
    if (this.busy) return
    this.busy = true

    try {
      const response = await fetch(url, {
        method: "PATCH",
        credentials: "same-origin",
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
        },
        body
      })
      if (!response.ok) throw new Error(`Move failed: ${response.status}`)
      const stream = await response.text()
      this.#preserveScrollOnReplace()
      Turbo.renderStreamMessage(stream)
    } catch (error) {
      notify("Could not move bullet")
    } finally {
      this.busy = false
    }
  }

  #preserveScrollOnReplace() {
    const boardId = this.element.id
    const boardScrollLeft = this.element.scrollLeft
    const laneScrollTops = new Map(this.laneTargets.map((lane) => [
      lane.dataset.lane,
      lane.querySelector(".collection--bullets")?.scrollTop ?? 0
    ]))

    const beforeRender = (event) => {
      if (event.target.getAttribute("target") !== boardId) return
      document.removeEventListener("turbo:before-stream-render", beforeRender)

      const render = event.detail.render
      event.detail.render = async (streamElement) => {
        await render(streamElement)
        const board = document.getElementById(boardId)
        if (!board) return

        board.scrollLeft = boardScrollLeft
        board.querySelectorAll(".collection--lane").forEach((lane) => {
          const list = lane.querySelector(".collection--bullets")
          if (list) list.scrollTop = laneScrollTops.get(lane.dataset.lane) ?? 0
        })
      }
    }

    document.addEventListener("turbo:before-stream-render", beforeRender)
  }
}

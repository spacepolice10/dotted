import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["count", "completed"]

  connect() {
    if (this.hasCompletedTarget) {
      this.completedBaseline = Number(this.completedTarget.dataset.completedCount)
      this.initialVisibleCompleted = this.#visibleCompletedCount()
    }

    this.observer = new MutationObserver(() => this.update())
    this.observer.observe(this.element, { childList: true })
    this.update()
  }

  disconnect() {
    this.observer?.disconnect()
  }

  update() {
    const count = this.element.querySelectorAll(":scope > .bullet:not(.bullet--pending), :scope > .bullet--current").length
    this.countTarget.textContent = `${count} ${count === 1 ? "bullet" : "bullets"} loaded`

    if (this.hasCompletedTarget) {
      const completed = Math.max(0, this.completedBaseline + this.#visibleCompletedCount() - this.initialVisibleCompleted)
      this.completedTarget.textContent = `${completed} ${completed === 1 ? "bullet" : "bullets"} completed`
    }
  }

  #visibleCompletedCount() {
    return this.element.querySelectorAll(
      ':scope > .bullet[data-bullet-done="true"], :scope > .bullet--current > .bullet[data-bullet-done="true"]'
    ).length
  }
}

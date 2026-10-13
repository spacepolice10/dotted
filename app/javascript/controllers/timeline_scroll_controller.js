import { Controller } from "@hotwired/stimulus"
import { keepScroll, pauseInertiaScroll, scrollToBottom } from "helpers/scroll_helpers"

// Generic timeline list mounted directly on its scroller (scrollport + list in one),
// opens at the newest bullet and pulls older pages from the top. The composer is a
// sibling flex row, so this element owns all remaining space and scrolling.
//
// A `current` rail (`bullets#show`) is already complete and anchored on one row:
// it centres that row instead of resting on the newest, and has no older page
// to pull or new row to follow.
export default class extends Controller {
  static targets = ["trigger"]
  static values = { path: String, rootMargin: { type: String, default: "400px" }, current: Boolean }

  initialize() {
    this.loading = false
  }

  connect() {
    // A current rail is whole and has no composer, so the machinery below
    // has nothing to act on.
    if (this.currentValue) return this.#openAtCurrent()

    scrollToBottom(this.element)
  }

  disconnect() {
    this.triggerObserver?.disconnect()
  }

  triggerTargetConnected(trigger) {
    this.#observeTrigger(trigger)
  }

  // Instant on purpose: the rail paints at the final offset already, so a
  // smooth glide in from the top reads as a mistake rather than an arrival.
  #openAtCurrent() {
    const current = this.element.querySelector('[aria-current="true"]')

    current?.scrollIntoView({ block: "center" })
  }

  // IntersectionObserver only reports changes, so a trigger that stays on screen
  // after a prepend would go quiet. Re-observing asks for a fresh reading, and
  // the loop ends as soon as the new rows push the trigger out of range.
  #observeTrigger(trigger) {
    this.triggerObserver?.disconnect()
    this.triggerObserver = new IntersectionObserver(
      ([entry]) => entry.isIntersecting && this.#loadPrevPage(),
      { root: this.element, rootMargin: this.rootMarginValue }
    )
    this.triggerObserver.observe(trigger)
  }

  async #loadPrevPage() {
    if (this.loading) return

    const cursor = this.#oldestRailId
    if (!cursor) return this.#stopLoadingPrevPage()

    this.loading = true

    try {
      const url = new URL(this.pathValue, window.location.origin)
      url.searchParams.set("before", cursor)

      const response = await fetch(url.toString(), {
        headers: { Accept: "text/html" }
      })

      if (response.status === 204) return this.#stopLoadingPrevPage()
      if (!response.ok) return

      this.#prepend(await response.text())
    } finally {
      this.loading = false
    }
  }

  #prepend(html) {
    const template = document.createElement("template")
    template.innerHTML = html

    pauseInertiaScroll(this.element)
    keepScroll(this.element, () => {
      const fragment = this.#mergeBoundarySection(template.content)
      // The trigger is the scroller's first child (it owns the pinning auto
      // margin), so older rows slot in right after it.
      if (this.hasTriggerTarget) {
        this.triggerTarget.after(fragment)
      } else {
        this.element.prepend(fragment)
      }
    })
    if (this.hasTriggerTarget) this.#observeTrigger(this.triggerTarget)
  }

  // A page can end mid-section (a week or day split across two requests). Its
  // last section then continues the one already on screen, so its rows move
  // there instead of duplicating the heading.
  #mergeBoundarySection(fragment) {
    const incoming = [...fragment.children].filter((child) => child.matches(".timeline--section[id]")).at(-1)
    const existing = incoming && this.element.querySelector(`.timeline--section[id="${incoming.id}"]`)
    if (!existing) return fragment

    const rows = [...incoming.children].filter((child) => !child.matches("h2"))
    const anchor = existing.querySelector(":scope > :not(h2)")
    anchor ? anchor.before(...rows) : existing.append(...rows)
    incoming.remove()

    return fragment
  }

  #stopLoadingPrevPage() {
    this.triggerObserver?.disconnect()
    this.triggerObserver = null
    if (this.hasTriggerTarget) this.triggerTarget.remove()
  }

  get #oldestRailId() {
    const frame = [...this.element.querySelectorAll("turbo-frame.bullet[id]")].find((el) =>
      /^bullet_\d+$/.test(el.id)
    )
    return frame?.id?.split("_").pop()
  }
}

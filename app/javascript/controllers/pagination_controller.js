import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "nextPageLink" ]
  static values = { rootMargin: String, turboFrame: String }

  nextPageLinkTargetConnected(link) {
    if (link.dataset.preload == "true") {
      this.#loadNextPage(link)
    } else {
      this.#waitForIntersection(link).then(() => this.#loadNextPage(link))
    }
  }

  async #loadNextPage(link) {
    const html = await this.#fetchNextPageHTML(link.href)
    await this.#nextFrame()
    link.outerHTML = html
  }

  async #fetchNextPageHTML(url) {
    const headers = { Accept: "text/html" }
    if (this.hasTurboFrameValue) {
      headers["Turbo-Frame"] = this.turboFrameValue
    }

    // window.fetch, not request.js: Turbo.fetch consumes frame responses before we can parse HTML.
    const response = await window.fetch(url, { headers })
    const doc = new DOMParser().parseFromString(await response.text(), "text/html")
    const container = this.#paginationContainerFrom(doc)
    return container ? container.innerHTML.trim() : ""
  }

  #paginationContainerFrom(doc) {
    if (this.element.id) {
      const byId = doc.getElementById(this.element.id)
      if (byId) return byId
    }

    if (this.hasTurboFrameValue) {
      const frame = doc.getElementById(this.turboFrameValue)
      const inFrame = frame?.querySelector(`[data-controller~="${this.identifier}"]`)
      if (inFrame) return inFrame
    }

    return doc.querySelector(`[data-controller~="${this.identifier}"]`)
  }

  #waitForIntersection(element) {
    const rootMargin = this.rootMarginValue || "200px"
    return new Promise(resolve => {
      new IntersectionObserver(([ entry ], observer) => {
        if (!entry.isIntersecting) return
        observer.disconnect()
        resolve()
      }, { rootMargin }).observe(element)
    })
  }

  #nextFrame() {
    return new Promise(resolve => requestAnimationFrame(resolve))
  }

  get nextPageLink() {
    const links = this.nextPageLinkTargets
    return links[links.length - 1]
  }
}

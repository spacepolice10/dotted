import { scrollToBottom } from "helpers/scroll_helpers"

export function clientId() {
  if (globalThis.crypto?.randomUUID) return crypto.randomUUID()

  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (char) => {
    const random = (Math.random() * 16) | 0
    const replacement = char === "x" ? random : (random & 0x3) | 0x8
    return replacement.toString(16)
  })
}

export function notify(message, type = "errmsg") {
  const host = document.getElementById("toasts")
  if (!host) return

  const el = document.createElement("div")
  el.className = `toasts--message toasts--${type}`
  el.dataset.toastsTarget = type
  el.setAttribute("role", type === "errmsg" ? "alert" : "status")
  el.setAttribute("aria-live", type === "errmsg" ? "assertive" : "polite")
  el.textContent = message
  host.replaceChildren(el)
}

export function removePending(id) {
  document.getElementById(`bullet_client_${id}`)?.remove()
}

export function failPending(id, message = "Could not save") {
  const el = document.getElementById(`bullet_client_${id}`)
  if (!el) return

  el.classList.add("bullet--pending-failed")
  let status = el.querySelector("[data-pending-status]")
  if (!status) {
    status = document.createElement("small")
    status.dataset.pendingStatus = ""
    status.className = "bullet--pending-status"
    el.querySelector(".bullet--content")?.append(status)
  }
  status.textContent = message
  el.addEventListener("click", () => el.remove(), { once: true })
}

export function insertPending(template, container, id, fill) {
  const node = template.content.cloneNode(true)
  const frame = node.querySelector("turbo-frame")
  frame.id = `bullet_client_${id}`
  fill(node)
  container.append(node)
  const scroller = container.closest(".timeline--scroller")
  if (scroller) scrollToBottom(scroller)
}

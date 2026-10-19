import { Controller } from "@hotwired/stimulus"
import { postponeDates } from "helpers/postpone_dates"
import { navigateCombobox } from "helpers/combobox"

const dateLabel = new Intl.DateTimeFormat("en", { weekday: "short", month: "long", day: "numeric", year: "numeric", timeZone: "UTC" })

export default class extends Controller {
  static targets = ["textfield", "defaults", "results", "hint", "template"]
  static values = { today: String }

  connect() {
    this.search()
    if (this.textfieldTarget.autofocus) this.textfieldTarget.focus()
  }

  search() {
    const query = this.textfieldTarget.value.trim()
    const dates = postponeDates(query, this.todayValue)
    this.defaultsTarget.hidden = !!query
    this.resultsTarget.hidden = !query
    this.hintTarget.hidden = !query || dates.length > 0
    this.resultsTarget.replaceChildren(...dates.map((date) => {
      const item = this.templateTarget.content.firstElementChild.cloneNode(true)
      item.querySelector("button").value = date
      item.querySelector("[data-date-label]").textContent = dateLabel.format(new Date(`${date}T00:00:00Z`))
      return item
    }))
  }

  navigate(event) {
    if (event.isComposing || event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return
    const list = this.defaultsTarget.hidden ? this.resultsTarget : this.defaultsTarget
    const buttons = [...list.querySelectorAll("button")]

    if (event.key === "Enter" && event.target === this.textfieldTarget) {
      event.preventDefault()
      if (buttons[0]) buttons[0].form.requestSubmit(buttons[0])
    } else if (["ArrowDown", "ArrowUp"].includes(event.key)) {
      event.preventDefault()
      const direction = event.key === "ArrowDown" ? "down" : "up"
      const index = navigateCombobox(buttons.indexOf(event.target), direction, buttons.length)
      const target = buttons[index] || this.textfieldTarget
      target.focus()
    } else if (event.key === "Escape" && this.textfieldTarget.value.trim()) {
      event.preventDefault()
      event.stopPropagation()
      this.textfieldTarget.value = ""
      this.search()
      this.textfieldTarget.focus()
    }
  }
}

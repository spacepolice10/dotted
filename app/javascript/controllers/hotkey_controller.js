import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  click(event) {
    if (this.#isClickable && !this.#shouldIgnore(event)) {
      event.preventDefault();
      this.element.click();
    }
  }

  focus(event) {
    if (!this.#shouldIgnore(event)) {
      event.preventDefault();
      this.element?.closest("input, textarea, [contenteditable], lexxy-editor, .lexxy-editor__content")?.focus();
    }
  }

  #shouldIgnore(event) {
    return event.defaultPrevented ||
      event.target.closest("input, textarea, [contenteditable], lexxy-editor, .lexxy-editor__content");
  }

  get #isClickable() {
    return getComputedStyle(this.element).pointerEvents !== "none";
  }
}

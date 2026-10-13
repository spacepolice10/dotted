import { Controller } from "@hotwired/stimulus";

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export default class extends Controller {
  static targets = ["input"];

  connect() {
    this.validate();
  }

  validate() {
    const input = this.inputTarget;
    const value = input.value.trim();

    if (value == "") {
      input.setCustomValidity("");
      return;
    }

    input.setCustomValidity(EMAIL_PATTERN.test(value) ? "" : "Enter a valid email address");
  }

  report(event) {
    event.preventDefault();
    this.inputTarget.reportValidity();
  }
}

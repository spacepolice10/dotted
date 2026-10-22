import { Controller } from "@hotwired/stimulus";

const PHONE_PATTERN = /^[+]?[\d\s().-]{7,}$/;

export default class extends Controller {
  static targets = ["input"];

  validate() {
    const input = this.inputTarget;
    const value = input.value.trim();

    if (value == "") {
      input.setCustomValidity("");
      return;
    }

    const digits = value.replace(/\D/g, "");
    const valid = digits.length >= 7 && PHONE_PATTERN.test(value);

    input.setCustomValidity(valid ? "" : "Enter a valid phone number");
  }

  report(event) {
    event.preventDefault();
    this.inputTarget.reportValidity();
  }
}

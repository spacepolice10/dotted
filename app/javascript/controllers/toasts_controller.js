import { Controller } from "@hotwired/stimulus";

const FADE_AWAY_MS = 3200;

export default class extends Controller {
  static targets = ["errmsg", "notify"];

  errmsgTargetConnected(element) {
    this.#scheduleDismiss(element);
  }

  notifyTargetConnected(element) {
    this.#scheduleDismiss(element);
  }

  #scheduleDismiss(element) {
    if (element.dataset.toastsDismissScheduled == "true") return;
    element.dataset.toastsDismissScheduled = "true";

    const remove = () => {
      cleanup();
      if (element.isConnected) element.remove();
    };

    const onAnimationEnd = (event) => {
      if (event.animationName == "toasts--fade-away") remove();
    };

    const cleanup = () => {
      element.removeEventListener("animationend", onAnimationEnd);
      window.clearTimeout(fallbackId);
    };

    element.addEventListener("animationend", onAnimationEnd);
    const fallbackId = window.setTimeout(remove, FADE_AWAY_MS);
  }
}

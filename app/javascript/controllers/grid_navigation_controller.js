import { Controller } from "@hotwired/stimulus";
import { navigateGrid } from "helpers/grid_navigation";

export default class extends Controller {
  static values = { columns: Number };
  static targets = ["item"];

  connect() {
    this.currentPosition = 0;
    this.focusPending = false;
    this.initTabindex();

    this.abortController = new AbortController();
    const { signal } = this.abortController;
    this.element.addEventListener("turbo:frame-load", this.onFrameLoad.bind(this), { signal });
  }

  disconnect() {
    this.abortController?.abort();
  }

  onFrameLoad() {
    if (!this.#isVisible()) return;
    this.focusFirst();
  }

  focusFirst() {
    this.currentPosition = 0;
    this.focusPending = true;
    this.#focusWhenReady();
  }

  navigate(event) {
    const directions = {
      ArrowLeft: "left",
      ArrowRight: "right",
      ArrowUp: "up",
      ArrowDown: "down",
    };
    const direction = directions[event.key];
    if (!direction) return;

    event.preventDefault();

    const next = navigateGrid(
      this.currentPosition,
      direction,
      this.columnsValue,
      this.itemTargets.length,
    );
    this.moveTo(next);
  }

  syncPosition(event) {
    const position = this.itemTargets.indexOf(event.target);
    if (position == -1) return;

    this.currentPosition = position;
    this.initTabindex();
  }

  moveTo(position) {
    this.currentPosition = position;
    this.initTabindex();
    this.itemTargets[position]?.focus();
  }

  itemTargetConnected() {
    if (this.focusPending) {
      this.#focusWhenReady();
      return;
    }

    this.initTabindex();
  }

  itemTargetDisconnected() {
    this.initTabindex();
  }

  initTabindex() {
    const items = this.itemTargets;
    if (!items.length) return;

    this.currentPosition = Math.min(this.currentPosition, items.length - 1);
    items.forEach((item, index) => {
      item.setAttribute("tabindex", index == this.currentPosition ? "0" : "-1");
    });
  }

  #isVisible() {
    const dialog = this.element.closest("dialog");
    if (!dialog) return this.element.isConnected;
    return dialog.open;
  }

  #focusWhenReady(attempt = 0) {
    if (!this.focusPending) return;

    if (this.itemTargets.length > 0) {
      this.focusPending = false;
      requestAnimationFrame(() => this.moveTo(this.currentPosition));
      return;
    }

    if (attempt < 20) {
      requestAnimationFrame(() => this.#focusWhenReady(attempt + 1));
    } else {
      this.focusPending = false;
    }
  }
}

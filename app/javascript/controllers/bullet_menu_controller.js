import { Controller } from "@hotwired/stimulus";
import { notify } from "helpers/composer_helpers";

export default class extends Controller {
  static targets = [
    "list",
    "menu",
    "card",
    "checkbox",
    "idList",
    "amount",
    "complete",
    "uncomplete",
    "publish",
    "unpublish",
    "copyLink",
    "pickerElement",
  ];

  static values = {
    idList: { type: Array, default: [] },
    selectMode: { type: Boolean, default: false },
  };

  connect() {
    this.beforeVisitHandler = () => this.#restore();
    this.submitEndHandler = (event) => this.#handleSubmitEnd(event);
    document.addEventListener("turbo:before-visit", this.beforeVisitHandler);
    document.addEventListener("turbo:submit-end", this.submitEndHandler);
    this.#syncSelectMode();
  }

  disconnect() {
    document.removeEventListener("turbo:before-visit", this.beforeVisitHandler);
    document.removeEventListener("turbo:submit-end", this.submitEndHandler);
  }

  toggle(event) {
    const checkbox = event.currentTarget;
    if (checkbox.closest("[data-bullet-menu-ignore]")) {
      checkbox.checked = false;
      return;
    }
    const id = checkbox.value;

    if (checkbox.checked) {
      if (!this.idListValue.includes(id))
        this.idListValue = [...this.idListValue, id];
    } else {
      this.idListValue = this.idListValue.filter((value) => value != id);
    }
  }

  idListValueChanged() {
    const csv = this.idListValue.join(",");

    this.idListTargets.forEach((input) => {
      input.value = csv;
    });

    const wasHidden = this.hasMenuTarget ? this.menuTarget.hidden : true;

    if (this.hasMenuTarget) {
      this.menuTarget.hidden = this.idListValue.length == 0;
    }

    if (this.hasAmountTarget) {
      const label = `${this.idListValue.length} selected`;
      this.amountTargets.forEach((el) => {
        el.textContent = label;
      });
    }

    if (this.hasMenuTarget && this.idListValue.length > 0) {
      this.menuTarget.focus({ preventScroll: true });
      // Keep a manually collapsed menu compact while selecting more bullets.
      if (wasHidden && this.hasCardTarget) this.cardTarget.open = true;
    }

    this.selectModeValue = this.idListValue.length > 0;
    this.#syncStatusActions();
  }

  selectModeValueChanged() {
    this.#syncSelectMode();
  }

  checkboxTargetConnected(checkbox) {
    checkbox.checked = this.idListValue.includes(checkbox.value);
    this.#syncStatusActions();
  }

  checkboxTargetDisconnected(checkbox) {
    if (!checkbox.checked) return;

    this.idListValue = this.idListValue.filter((value) => value != checkbox.value);
  }

  idListTargetConnected(input) {
    input.value = this.idListValue.join(",");
  }

  openPicker(event) {
    if (this.idListValue.length == 0) return;

    const { dialog: dialogId, url: path } = event.params;
    const picker = this.pickerElementTargets.find((target) => target.closest("dialog")?.id == dialogId);
    if (!picker || !path) return;
    const dialog = picker.closest("dialog");

    const url = new URL(path, window.location.origin);
    url.searchParams.set("bullet_ids", this.idListValue.join(","));
    picker.src = url.pathname + url.search;

    if (dialog.open) return;

    try {
      dialog.showModal();
    } catch (error) {
      if (error.name != "InvalidStateError") throw error;

      dialog.close();
      dialog.showModal();
    }
  }

  clear() {
    this.#restore();
  }

  async copyLink() {
    const selected = this.checkboxTargets.filter((checkbox) => checkbox.checked);
    if (selected.length != 1) return;

    const url = selected[0].dataset.publicUrl;
    if (!url) return;

    try {
      await navigator.clipboard.writeText(url);
      notify("Publish link copied", "notify");
    } catch {
      notify("Could not copy publish link");
    }
  }

  escape(event) {
    if (event.defaultPrevented) return;
    if (this.idListValue.length == 0) return;

    // An open picker closes itself natively — keep the selection intact.
    if (this.#isPickerOpen()) return;

    this.#cleanupSelection();
  }

  // =====================================================================
  // Picker dialogs
  // =====================================================================

  #closePickers() {
    this.pickerElementTargets.forEach((picker) => {
      const dialog = picker.closest("dialog");
      if (dialog.open) dialog.close();
    });
  }

  #isPickerOpen() {
    return this.pickerElementTargets.some((picker) => picker.closest("dialog")?.open);
  }

  // =====================================================================
  // Form submit + selection reset
  // =====================================================================

  #handleSubmitEnd(event) {
    if (!event.detail.success) return;

    const form = event.target;
    if (!(form instanceof HTMLFormElement) || form.method.toLowerCase() == "get") return;

    const inMenu = this.hasMenuTarget && this.menuTarget.contains(form);
    const inPicker = this.pickerElementTargets.some((picker) => picker.contains(form));
    if (inMenu || inPicker) this.#restore();
  }

  #restore() {
    this.#closePickers();
    this.#cleanupSelection();
  }

  #cleanupSelection() {
    this.idListValue = [];
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = false;
    });
  }

  // =====================================================================
  // Status actions (complete / publish)
  // =====================================================================

  #syncStatusActions() {
    const checked = this.checkboxTargets.filter((checkbox) => checkbox.checked);
    const done = this.#sharedDataset(checked, "bulkDone");
    const published = this.#sharedDataset(checked, "bulkPublished");

    if (this.hasCompleteTarget) this.completeTarget.hidden = done != "false";
    if (this.hasUncompleteTarget) this.uncompleteTarget.hidden = done != "true";
    if (this.hasPublishTarget) this.publishTarget.hidden = published != "false";
    if (this.hasUnpublishTarget) this.unpublishTarget.hidden = published != "true";
    if (this.hasCopyLinkTarget) {
      const singlePublished = checked.length == 1 && checked[0].dataset.bulkPublished == "true";
      this.copyLinkTarget.hidden = !singlePublished;
    }
  }

  #sharedDataset(checkboxes, key) {
    if (checkboxes.length == 0) return null;

    const value = checkboxes[0].dataset[key];
    return checkboxes.every((checkbox) => checkbox.dataset[key] == value)
      ? value
      : null;
  }

  // =====================================================================
  // Select mode sync
  // =====================================================================

  #syncSelectMode() {
    if (!this.hasListTarget) return;

    if (this.selectModeValue) {
      this.listTarget.dataset.mode = "select";
    } else {
      delete this.listTarget.dataset.mode;
    }
  }
}

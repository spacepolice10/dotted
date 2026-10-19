import { Controller } from "@hotwired/stimulus";
import { notify } from "helpers/composer_helpers";

export default class extends Controller {
  static targets = [
    "list",
    "menu",
    "checkbox",
    "bulletRow",
    "selectionLines",
    "idList",
    "amount",
    "complete",
    "uncomplete",
    "publishing",
    "publishingLink",
    "publishingTemplate",
    "note",
    "pickerElement",
  ];

  static values = {
    idList: { type: Array, default: [] },
    selectMode: { type: Boolean, default: false },
  };

  connect() {
    this.queueSelectionLines = () => {
      if (this.selectionLinesFrame) return;
      this.selectionLinesFrame = requestAnimationFrame(() => {
        this.selectionLinesFrame = null;
        this.#drawSelectionLines();
      });
    };
    this.beforeVisitHandler = () => this.#restore();
    this.submitEndHandler = (event) => this.#handleSubmitEnd(event);
    document.addEventListener("turbo:before-visit", this.beforeVisitHandler);
    document.addEventListener("turbo:submit-end", this.submitEndHandler);
    this.#syncSelectMode();
    this.queueSelectionLines();
  }

  disconnect() {
    if (this.selectionLinesFrame) cancelAnimationFrame(this.selectionLinesFrame);
    document.removeEventListener("turbo:before-visit", this.beforeVisitHandler);
    document.removeEventListener("turbo:submit-end", this.submitEndHandler);
  }

  listTargetConnected() {
    this.queueSelectionLines?.();
  }

  listTargetDisconnected() {
    this.queueSelectionLines?.();
  }

  bulletRowConnected() {
    this.queueSelectionLines?.();
  }

  bulletRowDisconnected() {
    this.queueSelectionLines?.();
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

  idListValueChanged(ids, previousIds = []) {
    this.publishingTargets.forEach((panel) => {
      panel.replaceChildren(this.publishingTemplateTarget.content.cloneNode(true));
    });
    this.publishingLinkTargets.forEach((link) => this.#updatePublishingLink(link));
    this.#updateMenu(ids.length > 0 && previousIds.length == 0);
    this.queueSelectionLines?.();
  }

  #updateMenu(opening) {
    const csv = this.idListValue.join(",");

    this.idListTargets.forEach((input) => {
      input.value = csv;
    });

    if (this.hasMenuTarget) {
      this.menuTarget.hidden = this.idListValue.length == 0;
    }

    if (this.hasAmountTarget) {
      const label = `${this.idListValue.length} selected`;
      this.amountTargets.forEach((el) => {
        el.textContent = label;
      });
    }

    if (this.hasMenuTarget && opening) {
      this.menuTarget.focus({ preventScroll: true });
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
    this.queueSelectionLines?.();
  }

  checkboxTargetDisconnected(checkbox) {
    if (checkbox.checked && !this.checkboxTargets.some((target) => target !== checkbox && target.value == checkbox.value)) {
      this.idListValue = this.idListValue.filter((value) => value != checkbox.value);
    }
    this.queueSelectionLines?.();
  }

  idListTargetConnected(input) {
    input.value = this.idListValue.join(",");
  }

  openNote() {
    if (this.idListValue.length != 1) return;
    const checkbox = this.checkboxTargets.find((checkbox) => checkbox.checked);
    if (!checkbox) return;
    this.#closePickers();
    this.openPicker({ params: { dialog: "note_dialog", url: checkbox.dataset.noteUrl } });
  }

  openPicker(event) {
    if (this.idListValue.length == 0) return;

    const { dialog: dialogId, url: path } = event.params;
    const picker = this.pickerElementTargets.find((target) => target.closest("dialog")?.id == dialogId);
    if (!picker) return;
    const dialog = picker.closest("dialog");

    if (path) {
      const url = new URL(path, window.location.origin);
      url.searchParams.set("bullet_ids", this.idListValue.join(","));
      picker.src = url.pathname + url.search;
    }

    if (dialog.open) return;

    try {
      dialog.showModal();
    } catch (error) {
      if (error.name != "InvalidStateError") throw error;

      dialog.close();
      dialog.showModal();
    }
  }

  publishingLinkTargetConnected(link) {
    this.#updatePublishingLink(link);
  }

  #updatePublishingLink(link) {
    const url = new URL(link.href);
    url.searchParams.set("bullet_ids", this.idListValue.join(","));
    link.href = url.href;
  }

  async copyLink(event) {
    const url = event.params.url;
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

    if (form.dataset.bulletMenuPreserveSelection == "true") return;

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
  // Status actions
  // =====================================================================

  #syncStatusActions() {
    const checked = this.checkboxTargets.filter((checkbox) => checkbox.checked);
    this.noteTargets.forEach((target) => {
      target.hidden = checked.length != 1;
    });
    const done = this.#sharedDataset(checked, "bulkDone");

    if (this.hasCompleteTarget) this.completeTarget.hidden = done != "false";
    if (this.hasUncompleteTarget) this.uncompleteTarget.hidden = done != "true";
  }

  #drawSelectionLines() {
    const svg = this.selectionLinesTarget;
    if (!svg) return;

    const selectedByBullet = new Map();
    this.checkboxTargets.forEach((checkbox) => {
      if (!checkbox.checked || !checkbox.isConnected) return;
      const bullet = checkbox.closest(".bullet");
      if (!bullet || selectedByBullet.has(bullet)) return;

      const marker = bullet.querySelector(".bullet--select-checkbox, .bullet--select-square");
      if (!marker) return;
      const rect = marker.getBoundingClientRect();
      if (rect.width && rect.height) {
        selectedByBullet.set(bullet, {
          x: rect.left + rect.width / 2,
          y: rect.top + rect.height / 2,
          bullet,
        });
      }
    });

    const selected = [...selectedByBullet.values()].sort((a, b) => {
      if (a.bullet === b.bullet) return 0;
      return a.bullet.compareDocumentPosition(b.bullet) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1;
    });

    const list = selected[0]?.bullet.closest('[data-bullet-menu-target~="list"]');
    if (!list || selected.length < 2) {
      svg.setAttribute("hidden", "");
      svg.replaceChildren();
      return;
    }

    list.append(svg);
    svg.removeAttribute("hidden");
    const width = list.clientWidth;
    const height = Math.max(list.scrollHeight, list.clientHeight);
    svg.setAttribute("width", width);
    svg.setAttribute("height", height);
    svg.setAttribute("viewBox", `0 0 ${width} ${height}`);
    svg.replaceChildren();

    const listRect = list.getBoundingClientRect();
    const points = selected
      .filter(({ bullet }) => bullet.closest('[data-bullet-menu-target~="list"]') === list)
      .map(({ bullet }) => {
        const marker = bullet.querySelector(".bullet--select-checkbox, .bullet--select-square");
        const rect = marker.getBoundingClientRect();
        return {
          x: rect.left - listRect.left + list.scrollLeft - list.clientLeft + rect.width / 2,
          y: rect.top - listRect.top + list.scrollTop - list.clientTop + rect.height / 2,
        };
      });

    for (let index = 1; index < points.length; index++) {
      const current = points[index];
      const start = points[index - 1];
      const outsideX = Math.max(4, Math.min(start.x, current.x) - 18);
      const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
      path.setAttribute(
        "d",
        `M ${start.x} ${start.y} C ${outsideX} ${start.y}, ${outsideX} ${current.y}, ${current.x} ${current.y}`,
      );
      svg.append(path);
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

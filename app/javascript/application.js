// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails";
import "controllers";
import * as ActiveStorage from "@rails/activestorage";

ActiveStorage.start();

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker.js").catch((error) => {
      console.warn("Service worker registration failed:", error);
    });
  });
}

import * as Lexxy from "lexxy";

Lexxy.configure({
  default: {
    toolbar: false,
  },
  simple: {
    attachments: false,
    toolbar: false,
    multiLine: false,
    richText: true,
    markdown: true,
  },
});

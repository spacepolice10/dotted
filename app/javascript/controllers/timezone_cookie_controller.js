import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone
    if (!timezone) return

    const existingTimezone = document.cookie
      .split("; ")
      .find((row) => row.startsWith("timezone="))
      ?.split("=")[1]

    if (existingTimezone && decodeURIComponent(existingTimezone) == timezone) return

    const secureAttribute = window.location.protocol == "https:" ? "; secure" : ""
    document.cookie = `timezone=${encodeURIComponent(timezone)}; path=/; max-age=31536000; samesite=lax${secureAttribute}`
  }
}

# Stimulus

[Stimulus](https://stimulus.hotwired.dev) is Hotwire's modest JavaScript framework — it sprinkles behavior onto HTML via `data-*` attributes. No virtual DOM, no client-side router, no build step.

- **Upstream**: https://stimulus.hotwired.dev/reference/controllers
- **Reference projects**:
  - [Fizzy](https://github.com/basecamp/fizzy) — forms (composer, presence, combobox)
  - [Writebook](https://github.com/basecamp/writebook) — inline-edit controllers
  - [Campfire](https://github.com/basecamp/campfire) — message composer, search, presence
  - [Lexxy](https://github.com/basecamp/lexxy) — custom element patterns alongside Stimulus

## Core concepts

| Concept | Form | Purpose |
|---|---|---|
| Controller | `data-controller="name"` | Mounts a JS class on this element and its descendants |
| Action | `data-action="event->controller#method"` | Wires DOM events to controller methods |
| Target | `data-{controller}-target="name"` | Typed reference: `static targets = ["name"]` → `this.nameTarget` |
| Value | `data-{controller}-name-value="…"` | Typed reactive value; `static values = { id: Number }` → `this.idValue` |
| Outlet | `data-{controller}-target="other.outlet"` | Cross-controller reference |
| Class | `static classes = […]` | Add/remove CSS classes from a typed list |

Full reference: https://stimulus.hotwired.dev/reference/attributes

## How controllers are loaded

Importmap + `app/javascript/controllers/index.js` registers controllers with the Stimulus application. File naming: `{name}_controller.js` → `data-controller="{name}"`.

## Lifecycle

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static values = { url: String }

  connect()    { /* element entered DOM */ }
  disconnect() { /* element left DOM — remove document listeners here */ }

  urlValueChanged() { }
  inputTargetConnected(el) { }
  inputTargetDisconnected(el) { }
}
```

Always pair `document.addEventListener` in `connect` with `document.removeEventListener` in `disconnect`.

## Patterns to copy

- **Document-level key filters** — chords in the action descriptor (`keydown.ctrl+k@document->hotkey#click`), not hardcoded in the controller. Reference: Fizzy `hotkey_controller.js`.

- **Document-wide listeners** — bind on `document` or `window` in `connect`, remove in `disconnect`; clear transient UI on `blur`, `visibilitychange`, and `turbo:before-visit`.

- **Popovers backed by lazy turbo-frames** — set the frame `src`, then `showPopover()`; see `docs/_turbo.md`.

- **Turbo events to close flows** — prefer `data-action="turbo:submit-end->dialog#submitEnd"` over custom DOM events.

- **Statics over constructors** — declare targets, values, outlets, and classes as static members.

## When NOT to use Stimulus

- Heavy data-driven UI (large tables, canvas) — reach for a dedicated client framework.
- State that must survive full page reloads — use a hidden field or server-side state.
- Complex animation choreography — CSS-only is usually better.
- Business logic belongs server-side; Stimulus should be glue.

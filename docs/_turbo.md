# Turbo (Hotwire)

[Turbo](https://turbo.hotwired.dev) is the page-acceleration + DOM-patching layer of Hotwire. It accelerates links, scopes page regions to frames, and lets the server push DOM updates via streams. Plus page morphs for in-place refreshes.

- **Upstream**: https://turbo.hotwired.dev/reference/drive
- **Rails guide**: https://guides.rubyonrails.org/working_with_javascript_in_rails.html
- **Reference projects**:
  - [Fizzy](https://github.com/basecamp/fizzy) — cards-as-frames and nested frame navigation
  - [Writebook](https://github.com/basecamp/writebook) — stream actions on form submissions
  - [Campfire](https://github.com/basecamp/campfire) — broadcast streams + Action Cable for real-time
  - [Lexxy](https://github.com/basecamp/lexxy) — editor component handles Turbo morphing; study disconnect/reconnect

## The four Turbo features

| Feature | What it does | When to use |
|---|---|---|
| **Drive** | Intercepts link clicks + form submissions, fetches HTML, swaps `<body>`. | Default. Avoid full-page reloads. |
| **Frames** | Scoped navigation/updates inside a `<turbo-frame>`. Lazy-loads with `loading="lazy"`. | Partial page regions, pickers, lazy lists. |
| **Streams** | Server returns `<turbo-stream>` elements that patch the DOM by `action` + `target`. | Inline updates after form POSTs, bulk actions. |
| **Morph** | In-place `<body>` patch preserving focus, scroll, editor state. | Set via `<meta name="turbo-refresh-method" content="morph">`. |

## Conventions

### Frames as update targets

Wrap each independently-updatable row or panel in a `<turbo-frame id="…">`. Stream responses can `replace` or `update` that frame without touching the rest of the page.

Use `dom_id(record)` for stable, unique frame ids.

### Streams for mutating actions

Controllers respond to `format.turbo_stream` for inline updates and `format.html` for fallback redirects.

Stream templates live beside the controller (`create.turbo_stream.erb`). Failed actions can re-render the same template with `status: :unprocessable_entity` so error UI updates inline.

### Lazy popover frames

`<turbo-frame popover loading="lazy" src="…">` loads picker content on first open. Set `src` from Stimulus, then call `element.showPopover()`.

### Always provide HTML fallback

Every `format.turbo_stream` response should also handle `format.html` (redirect or render) so non-JS clients still work.

## Turbo events to know

| Event | When | Typical use |
|---|---|---|
| `turbo:submit-end` | After a form submission finishes. `event.detail.success` indicates HTTP 2xx. | Close dialogs, clear selection state |
| `turbo:before-visit` | Before any navigation. | Reset transient UI state |
| `turbo:before-render` | Before a cached snapshot is rendered. | Close stale `<dialog open>` in the incoming body |
| `turbo:before-morph-attribute` | Before morph patches an attribute. | Close dialogs when morph would remove `open` |
| `turbo:render` / `turbo:load` | After a new body is rendered. | — |
| `turbo:frame-load` | After a `<turbo-frame>` resolves. | — |

Full list: https://turbo.hotwired.dev/reference/events

## Stream actions cheatsheet

```erb
<%# Update target's contents %>
<%= turbo_stream.update "flash" do %>
  <%= render "shared/flash", messages: @errors %>
<% end %>

<%# Replace target entirely %>
<%= turbo_stream.replace dom_id(@record) %>

<%# Append / prepend / remove %>
<%= turbo_stream.append "list" %>
<%= turbo_stream.prepend "list" %>
<%= turbo_stream.remove dom_id(@record) %>
```

## Things to watch for

- **Morphing custom elements** — form-associated web components (e.g. Lexxy) must handle disconnect/reconnect; see `docs/_lexxy.md`.
- **Cached `<dialog open>`** — call `dialog.close()` in `turbo:before-render` (incoming body) and intercept `open` removal in `turbo:before-morph-attribute`. Never `removeAttribute("open")` on a modal dialog — it desyncs `.open` from the top layer ([Turbo #1239](https://github.com/hotwired/turbo/issues/1239)).
- **Frame IDs must be unique** on the page; don't reuse the same id on a frame and a plain element.
- **`data-turbo-action="advance"`** inside popovers often navigates unexpectedly — omit unless intentional.

## When NOT to use Turbo

- Full-page reloads are fine for OAuth callbacks or export downloads (`data: { turbo: false }`).
- Streams alone aren't a substitute for Action Cable when you need push from arbitrary server events.
- Don't use Turbo for cross-origin navigation without explicit configuration.

# Lexxy

[Lexxy](https://github.com/basecamp/lexxy) is Basecamp's modern Action Text editor, built on [Lexical](https://lexical.dev). Replaces Trix.

- **Upstream docs**: https://basecamp.github.io/lexxy
- **Prompts**: https://basecamp.github.io/lexxy/prompts.html
- **Source**: https://github.com/basecamp/lexxy
- **Reference projects**:
  - [Fizzy](https://github.com/basecamp/fizzy) — `@` / `#` prompts and rich composes
  - [Writebook](https://github.com/basecamp/writebook) — inline + expand composes for long-form content
  - [Campfire](https://github.com/basecamp/campfire) — message composes with attachments

## Core concepts

| Concept | What it is |
|---|---|
| `<lexxy-editor>` | Form-associated web component; `value` syncs to a hidden form field on change |
| Preset | Named config block passed via `preset="..."` and `Lexxy.configure({ name: {...} })` |
| `<lexxy-prompt>` | Trigger-based popover (`#`, `@`, `/`) for suggestions or commands |
| `<lexxy-prompt-item>` | Suggestion row with `<template type="menu">` and `<template type="editor">` |
| Custom attachment | Prompt selection inserts an Action Text attachment (via `sgid` + `content-type`) |
| File attachment | Active Storage blob inserted inline, or intercepted for direct upload |
| Custom events | `lexxy:change`, `lexxy:file-accept`, `lexxy:editor-initialized`, `lexxy:upload-*` |
| Extension | A `LexxyExtension` subclass; `lexicalExtension.register(editor)` returns cleanup |
| Sanitization | Lexxy widens Action Text's allowed tags/attrs; Loofah allows `var()` in CSS |

## Presets

Configure named presets in `Lexxy.configure` (typically in `app/javascript/application.js`):

```javascript
Lexxy.configure({
  inline: { toolbar: false, multiline: false },
  note:   { toolbar: true,  multiline: true, markdown: true, attachments: true }
})
```

Use `preset="inline"` or `preset="note"` on `<lexxy-editor>` (or the Rails `rich_text_area` helper).

Register global extensions via `global.extensions` in the preset config.

## Prompts

Follow Lexxy's [custom attachments with remote loading](https://basecamp.github.io/lexxy/prompts.html) pattern.

Remote prompts use `remote-filtering` and `supports-space-in-searches`. Lexxy sends **`filter`**, not `q`.

Each `lexxy-prompt-item` provides:

- `search` — text matched when filtering
- `sgid` — attachable signed global id for Action Text
- `template[type="menu"]` — dropdown row
- `template[type="editor"]` — HTML embedded in the attachment when selected

Suggestion endpoints return HTML fragments of prompt items. Attachables implement `to_attachable_partial_path` for read views and editor pill partials for write views.

## Direct uploads

Enable attachments in the preset, then handle `lexxy:file-accept` if files should bypass inline rich-text embedding (Active Storage direct upload flow).

## Attachment hydration

Stored Action Text HTML keeps lightweight attachment references. On load, `rich_text_area` hydrates them via the gem's `render_custom_attachments_in` (each attachable's `to_attachable_partial_path`).

## Turbo morph

The `<lexxy-editor>` web component handles disconnect/reconnect to survive Turbo Drive morphs without losing value or focus.

## Debugging

- `document.querySelector('lexxy-editor').value` — current editor HTML
- `LexicalEditorElement.debug = true` in the console — verbose logging
- Watch `lexxy:editor-initialized` and `lexxy:change` on the editor element

## When NOT to use Lexxy

- Collaborative real-time editing — Lexxy is single-user; look at Lexical's Yjs bindings instead.
- No-JS editor — use a plain `text_area` and Action Text without an editor.
- iframe-isolated editors — Lexxy assumes same-document, form-associated context.
- Non-HTML embed contexts (PDF, RSS) — strip Action Text body to plain text first.

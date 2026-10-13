# Rails

Rails 8 cheatsheet — framework patterns and upstream docs, not application domain.

- **Guides**: https://guides.rubyonrails.org
- **API**: https://api.rubyonrails.org
- **Reference projects** (Rails 8 + Hotwire, idiomatic Basecamp style):
  - [Fizzy](https://github.com/basecamp/fizzy) — auth, concerns, delegated types, Lexxy
  - [Writebook](https://github.com/basecamp/writebook) — Action Text forms, service objects
  - [Campfire](https://github.com/basecamp/campfire) — Action Cable, Turbo Streams
  - [Lexxy](https://github.com/basecamp/lexxy) — Action Text editor gem (`docs/_lexxy.md`)

## Stack patterns

Common in modern Rails 8 apps using this toolchain:

| Area | Typical gems | Doc |
|---|---|---|
| Assets | `propshaft`, `importmap-rails` | [Working with JavaScript](https://guides.rubyonrails.org/working_with_javascript_in_rails.html) |
| Hotwire | `turbo-rails`, `stimulus-rails` | `docs/_turbo.md`, `docs/_stimulus.md` |
| Rich text | `lexxy` (or Action Text + Trix) | `docs/_lexxy.md` |
| Jobs / cache / cable | `solid_queue`, `solid_cache`, `solid_cable` | [Rails 8 release notes](https://guides.rubyonrails.org/8_0_release_notes.html) |

## Patterns

### Session auth without Devise

Custom `Authentication` concern on `ApplicationController`; per-controller opt-out. Session id in a signed, httponly cookie. `Current` object via `ActiveSupport::CurrentAttributes` for request-scoped user/session.

Reference: Fizzy `app/controllers/concerns/authentication.rb`.

### `ActiveSupport::Concern` for shared model behavior

Extract repeated associations, scopes, and intent methods into `app/models/concerns/`. Keep each concern focused on one behavior.

When the same verb means different things on different hosts, **namespace the concern** (`Model::Archivable`) instead of sharing one module with conflicting `after_*` hooks.

Reference: Fizzy `app/models/concerns/`.

### Delegated types

`delegated_type :role` stores `role_type` + `role_id` on the parent; concrete types are normal models. Prefer over STI when subtypes differ substantially.

- API: https://api.rubyonrails.org/classes/ActiveRecord/DelegatedType.html
- Guide: https://guides.rubyonrails.org/association_basics.html

### Delegated types + nested attributes

Parent declares `accepts_nested_attributes_for :role`. Strong params permit `role_attributes` keyed by `role_type`. Each delegated class can expose its own permitted attribute list so the controller derives the permit shape from the submitted type.

- Nested attributes: https://api.rubyonrails.org/classes/ActiveRecord/NestedAttributes/ClassMethods.html

### Action Text

`has_rich_text :content` stores HTML in `action_text_rich_texts`. Attachments serialize as `<action-text-attachment>` nodes. Custom attachables implement `ActionText::Attachable` (`content_type`, `to_attachable_partial_path`, `attachable_sgid`).

Rich text saves on the `ActionText::RichText` record — hook `after_save` on that model (via `ActiveSupport.on_load(:action_text_rich_text)`) when logic must run only on body changes, not parent saves.

- Guide: https://guides.rubyonrails.org/action_text_overview.html
- Editor: `docs/_lexxy.md`

### Active Storage direct uploads

Client uploads to storage via `DirectUpload`; the server receives a signed blob id. Intercept the editor's file-accept event when files should not become inline rich-text blobs.

- Guide: https://guides.rubyonrails.org/active_storage_overview.html#direct-uploads

### Request variants

`request.variant = :mobile` in a controller `before_action`; templates use the `+mobile.erb` suffix. Branch in shared templates with `request.variant.include?(:mobile)`.

- Guide: https://guides.rubyonrails.org/layouts_and_rendering.html#the-virtual-path-option

### Per-request timezone

Wrap actions in `Time.use_zone(zone) { yield }` where `zone` comes from a cookie or user preference. Avoid ad-hoc `Time.zone` overrides outside the wrapper.

### Routes

Prefer `scope module:` for namespaced controllers. Use singular `resource` for one-per-user pages. Small intent controllers (pin, archive, etc.) map cleanly to nested routes under a collection.

Reference: Fizzy routes and `scope module:` usage.

### SQLite + Solid adapters

One SQLite file per database role (`primary`, `cache`, `queue`, `cable` in `config/database.yml`). Solid Queue can run inside Puma (`SOLID_QUEUE_IN_PUMA`). No separate Redis process.

Trade-off: no Postgres-specific features (advanced full-text, JSONB operators, advisory locks).

### Testing

Minitest + fixtures; parallel by default (`bin/rails test`). System tests via Capybara + Selenium (`bin/rails test:system`).

Reference: Fizzy `test/`.

## Guides worth reading (in order)

1. [Action Text](https://guides.rubyonrails.org/action_text_overview.html)
2. [Active Storage](https://guides.rubyonrails.org/active_storage_overview.html)
3. [Active Record Query Interface](https://guides.rubyonrails.org/active_record_querying.html)
4. [Delegated Type](https://api.rubyonrails.org/classes/ActiveRecord/DelegatedType.html)
5. [Action Controller Overview](https://guides.rubyonrails.org/action_controller_overview.html)
6. [Layouts and Rendering](https://guides.rubyonrails.org/layouts_and_rendering.html)
7. [Working with JavaScript in Rails](https://guides.rubyonrails.org/working_with_javascript_in_rails.html)

## When this stack is a poor fit

- High-volume pub/sub fanout — Solid Cable suits modest scale; beyond that, use a dedicated broker.
- Postgres-only features while staying on SQLite.
- Very high job throughput — Solid Queue suits typical app load; heavy pipelines need a dedicated queue.
- Rich client-side application state — Hotwire covers most server-rendered UX; a SPA framework is warranted only when the UI genuinely needs it.

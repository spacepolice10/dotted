# JSON routes for a future CLI

Send `Accept: application/json` (or use the `.json` route suffix). Authenticate
with `Authorization: Bearer <access-code>`; create an access code on the Access
codes web page, or through the JSON email-code sign-in flow and
`POST /access_codes.json`. Browser sessions also work. JSON write requests
from a CLI do not need a CSRF token.

## Available operations

| Purpose | Routes | Response |
| --- | --- | --- |
| Email-code sign-in and sign-out | `POST /authentication`, `POST /authentication/confirmation`, `DELETE /authentication` | Pending code, session code, or 204 |
| Access codes | `GET/POST /access_codes`, `DELETE /access_codes/:id` | List, one-time secret, or 204 |
| Bullets | `GET/POST /bullets`, `GET/PATCH/DELETE /bullets/:id` | Bullet objects or 204 |
| Bulk bullet changes | `POST/DELETE /bullets/completion`, `POST /bullets/collect`, `POST /bullets/postpone`, `POST/DELETE /bullets/publish` | Array of changed bullets |
| Collections | `GET/POST /collections`, `GET/PATCH/DELETE /collections/:id` | Collection objects or 204 |
| Search | `GET /search/results?q=...` | Array of `{ id, type, name, url }` |
| Published bullets | `GET /published` | Array of bullet objects with `public_url` |
| Attachments | `GET /attachments`, `GET /attachments/:id` | File bullet ID, metadata, and download URL |
| Webhooks | `GET/POST /webhooks`, `DELETE /webhooks/:id` | List, one-time secret, or 204 |
| Webhook intake | `POST /webhooks/:code` | Created bullet |

`GET /` has the same JSON bullet feed as `GET /bullets`. The bullet feed
accepts `before` for paging and the existing `collection`, `completed`,
`from`, and `to` filters. For upcoming bullets, pass tomorrow's date as
`from`. Bulk actions accept comma-separated `bullet_ids`; at most
200 IDs can be sent, and every ID must belong to the signed-in user. Validation
errors return HTTP 422 with arrays of messages keyed by attribute. Missing
records return 404. Unauthenticated JSON requests return 401.

## Favorite collections

Collection JSON includes a `favorite` boolean. Set it with
`PATCH /collections/:id` and `{ "collection": { "favorite": true } }`, or send
`false` to remove the favorite. Favorite collections appear on the Index page.

## Webhook notes

`POST /webhooks/:code` accepts top-level `body`, optional `author_name`, and
optional `note` strings. Keep `body` as the short bullet summary and put longer
plain text or rich HTML in `note`. The bullet and its note are saved together;
omitting `note` or sending an empty string creates only the bullet. A nonempty
bullet body is still required. The webhook code authorizes the request without
a separate login.

```json
{
  "author_name": "CI",
  "body": "Build finished",
  "note": "<h2>Build report</h2><p>All checks passed. Full details go here.</p>"
}
```

The response remains the created bullet object with HTTP 201 and a `Location`
header pointing to its page. The note preview appears below the bullet, and the
full note is shown on that page.

## Routes that remain HTML or browser-focused

| Routes | Reason / CLI path |
| --- | --- |
| `/bullets/postpone/new`, `/bullets/collect/new`, `/collections/new`, `/collections/:id/edit`, `/webhooks/new` | Picker and form screens. Use the corresponding JSON list or write route. |
| `/search`, `/completed`, `/user` | Navigation screens. Use search results, filtered bullets, and access-code/webhook routes. |
| `/published/:code` | Public HTML page. A public JSON representation still needs an explicit exposure contract. |
| `/bullets/export` | Downloadable HTML export. Use the JSON bullet feed for machine-readable data. |
| `/manifest`, `/service-worker`, `/up` | System endpoints, not CLI data operations. |

The route table now declares only implemented publish actions; Rails previously
generated `new`, `edit`, `show`, and `update` routes for publish controllers
that have no matching actions.

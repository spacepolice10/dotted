# Dotted CLI

From the repository root, run `cargo run --manifest-path cli/Cargo.toml -- help`
to see the commands and their input/output contract.

Build the standalone executable for this Apple Silicon Mac with:

```sh
cargo build --release --locked --manifest-path cli/Cargo.toml
```

Cargo writes it to `cli/target/release/dotted-cli`. For repeatable Keychain
access, sign that release binary with a stable macOS code-signing identity:

```sh
security find-identity -v -p codesigning
codesign --force --sign "YOUR IDENTITY" --identifier app.dotted.cli cli/target/release/dotted-cli
codesign --verify --strict cli/target/release/dotted-cli
```

On this Mac, the local identity is `Dotted CLI Local Signing`; use that in place
of `YOUR IDENTITY`. It is intended for local use and is not an Apple Developer
ID for distribution to other Macs.

Use the same signed binary for `auth login` and later agent commands. Re-sign
after rebuilding. An ad hoc signature can cause repeat Keychain prompts.
See [the portable run guide](PORTABLE.md).

Create an access code on Dotted's web **Access codes** page. Copy it while it
is shown, then run:

```sh
cli/target/release/dotted-cli auth login https://your-dotted-server.example
```

The CLI prompts for the code without echoing it, verifies it with Dotted, and
saves the server URL and code together in macOS Keychain. Run
`cli/target/release/dotted-cli auth check` to verify the saved login.
`cli/target/release/dotted-cli auth logout` removes the Keychain item; revoke the code
on the web to disable it. Logging in again replaces the saved login. HTTPS is
required except for a local server at `localhost` or `127.0.0.1`.

Run `cli/target/release/dotted-cli bullet list` to read the
current page of bullets as indented JSON.
By default it returns at most 20 recent, incomplete bullets due through today.
Use `--all` to fetch every matching page. The output goes to stdout; errors go
to stderr with a nonzero exit status.

```sh
cli/target/release/dotted-cli bullet list --from 2026-10-01 --to 2026-10-13
cli/target/release/dotted-cli bullet list --collection "Ideas" --all
cli/target/release/dotted-cli bullet list --completed --from 2026-10-01
```

Dates are inclusive and use `YYYY-MM-DD`. `--collection` takes a collection
name. Explicit date ranges can include future bullets; `--completed` switches
from incomplete to completed bullets. `--all` follows the server's pagination
cursor and returns the combined result in date order.

For a temporary login, set both `DOTTED_URL` and `DOTTED_TOKEN` in the process
environment. These override the saved login for that invocation. Do not put
codes in command arguments, shell history, source files, or logs. The CLI never
prints a code.

Access codes have full account access and remain valid until revoked. Dotted
shows the code only when it is created; see [the JSON API guide](../docs/json-api.md)
for the email-code flow used to create one. Remove a code through
`DELETE /access_codes/:id` when it is no longer needed.

Agents working in this repository can start with [AGENTS.md](../AGENTS.md).

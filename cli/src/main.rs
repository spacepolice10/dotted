mod auth;
mod bullets;
mod credentials;

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();

    match args.as_slice() {
        [] => print_help(),
        [help] if matches!(help.as_str(), "help" | "--help" | "-h") => print_help(),
        [auth, login, url] if auth == "auth" && login == "login" => {
            if let Err(message) = credentials::login(url) {
                eprintln!("{message}");
                std::process::exit(1);
            }
            println!("Dotted login saved in macOS Keychain.");
        }
        [auth, logout] if auth == "auth" && logout == "logout" => {
            if let Err(message) = credentials::logout() {
                eprintln!("{message}");
                std::process::exit(1);
            }
            println!(
                "Saved login removed from macOS Keychain. Revoke the code on the web if needed."
            );
        }
        [auth, check] if auth == "auth" && check == "check" => {
            if let Err(message) = auth::check_current() {
                eprintln!("{message}");
                std::process::exit(1);
            }
            println!("Authenticated with Dotted.");
        }
        [bullet, list, rest @ ..] if bullet == "bullet" && list == "list" => {
            let options = match bullets::ListOptions::parse(rest) {
                Ok(options) => options,
                Err(message) => {
                    eprintln!("{message}");
                    std::process::exit(2);
                }
            };
            match bullets::list(&options) {
                Ok(bullets) => println!("{bullets}"),
                Err(message) => {
                    eprintln!("{message}");
                    std::process::exit(1);
                }
            }
        }
        [command, ..] => {
            eprintln!("Unknown command: {command}. Run 'dotted-cli help' for available commands.");
            std::process::exit(2);
        }
    }
}

fn print_help() {
    print!(
        r#"Dotted CLI

Usage: dotted-cli <command>

Commands:
  help                   Show this command contract; no credentials needed
  auth login URL         Verify and save a web-created access code; hidden prompt
  auth check             Verify the saved login with Dotted
  auth logout            Remove the saved login (does not revoke the code)
  bullet list [options]  Print a formatted JSON array of bullets to stdout

Bullet list options:
  --from YYYY-MM-DD       Include bullets on or after this date
  --to YYYY-MM-DD         Include bullets on or before this date
  --collection NAME       Filter by collection name
  --completed             List completed instead of incomplete bullets
  --all                   Fetch every matching page; otherwise show latest 20

Authentication:
  Create an access code on Dotted's web Access codes page, then run auth login
  with the server origin, such as https://dotted.example.com. Paste the code
  when prompted. The code is stored in macOS Keychain. Never put access codes
  in command arguments or logs.
  Access codes grant full account access. HTTPS is required except on localhost.
  For automation, set DOTTED_URL and DOTTED_TOKEN together in the process
  environment; they override the saved login for that invocation.

Output contract:
  With no filters, bullet list shows recent incomplete bullets due through today.
  Date bounds are inclusive; an explicit range can include future bullets.
  Errors go to stderr with a nonzero exit status; stdout is for results.
  Invalid options and unknown commands exit 2.

Using with agents:
  Ask the agent to run help first and use only the listed commands.
  If login is missing, run auth login yourself; never paste a code into a chat.
  Ask for --all when you need more than the latest 20 matching bullets.

Example prompts:
  "Show all incomplete bullets in my Ideas collection."
  "List completed bullets dated last month."
  "Summarize bullets due this week in the Work collection."
"#
    );
}

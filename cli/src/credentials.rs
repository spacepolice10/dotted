use std::env::{self, VarError};

use keyring::{Entry, Error};

use crate::auth;

const SERVICE: &str = "dotted-cli";
const ACCOUNT: &str = "default";
const NO_LOGIN: &str = "No saved login. Run 'dotted-cli auth login URL' first.";

pub fn current() -> Result<(String, String), String> {
    match (env::var("DOTTED_URL"), env::var("DOTTED_TOKEN")) {
        (Ok(url), Ok(token)) => {
            let url = auth::server_origin(&url)?;
            auth::validate_token(&token)?;
            Ok((url, token))
        }
        (Err(VarError::NotPresent), Err(VarError::NotPresent)) => load(),
        (Err(VarError::NotUnicode(_)), _) | (_, Err(VarError::NotUnicode(_))) => {
            Err("DOTTED_URL and DOTTED_TOKEN must contain text.".into())
        }
        _ => Err("Set both DOTTED_URL and DOTTED_TOKEN, or neither.".into()),
    }
}

pub fn login(url: &str) -> Result<(), String> {
    let url = auth::server_origin(url)?;
    let token = rpassword::prompt_password("Paste Dotted access code: ")
        .map_err(|_| "Could not read the access code from the terminal.".to_string())?;
    auth::check(&url, &token)?;
    entry()?
        .set_password(&format!("{url}\n{token}"))
        .map_err(|_| "Could not save the login in macOS Keychain.".to_string())
}

pub fn logout() -> Result<(), String> {
    match entry()?.delete_credential() {
        Ok(()) | Err(Error::NoEntry) => Ok(()),
        Err(_) => Err("Could not remove the login from macOS Keychain.".into()),
    }
}

fn load() -> Result<(String, String), String> {
    let saved = match entry()?.get_password() {
        Ok(saved) => saved,
        Err(Error::NoEntry) => return Err(NO_LOGIN.into()),
        Err(_) => return Err("Could not read the login from macOS Keychain.".into()),
    };
    decode(&saved)
}

fn entry() -> Result<Entry, String> {
    Entry::new(SERVICE, ACCOUNT).map_err(|_| "Could not open macOS Keychain.".to_string())
}

fn decode(saved: &str) -> Result<(String, String), String> {
    let (url, token) = saved
        .split_once('\n')
        .ok_or("Saved login is invalid. Run 'dotted-cli auth login URL' again.")?;
    auth::server_origin(url)
        .and_then(|origin| {
            auth::validate_token(token)?;
            Ok((origin, token.to_string()))
        })
        .map_err(|_| "Saved login is invalid. Run 'dotted-cli auth login URL' again.".into())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn saved_login_requires_a_valid_origin_and_code() {
        let valid = "https://dotted.example.com\ndj_AAAAAAAAAAAAAAAAAAAAAAAA";
        assert_eq!(
            decode(valid).unwrap(),
            (
                "https://dotted.example.com".into(),
                "dj_AAAAAAAAAAAAAAAAAAAAAAAA".into()
            )
        );
        for invalid in [
            "https://dotted.example.com",
            "http://dotted.example.com\ndj_AAAAAAAAAAAAAAAAAAAAAAAA",
            "https://dotted.example.com\ndj_bad",
            "https://dotted.example.com\ndj_AAAAAAAAAAAAAAAAAAAAAAAA\nextra",
        ] {
            assert!(decode(invalid).is_err());
        }
    }
}

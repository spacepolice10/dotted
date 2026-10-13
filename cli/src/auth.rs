use std::time::Duration;

pub fn check_current() -> Result<(), String> {
    let (url, token) = crate::credentials::current()?;
    check(&url, &token)
}

pub(crate) fn check(url: &str, token: &str) -> Result<(), String> {
    get_json(url, token, "/access_codes.json").map(|_| ())
}

fn get_json(url: &str, token: &str, path: &str) -> Result<String, String> {
    get_json_with_query(url, token, path, &[])?
        .ok_or_else(|| "Dotted returned no JSON.".to_string())
}

pub(crate) fn get_json_with_query(
    url: &str,
    token: &str,
    path: &str,
    query: &[(&str, &str)],
) -> Result<Option<String>, String> {
    let endpoint = format!("{}{}", server_origin(url)?, path);
    validate_token(token)?;

    let https = endpoint.starts_with("https://");
    let config = ureq::Agent::config_builder()
        .https_only(https)
        .max_redirects(0)
        .timeout_global(Some(Duration::from_secs(10)))
        .build();
    let agent: ureq::Agent = config.into();

    let mut request = agent
        .get(&endpoint)
        .header("Accept", "application/json")
        .header("Authorization", format!("Bearer {token}"));
    for &(name, value) in query {
        request = request.query(name, value);
    }

    match request.call() {
        Ok(mut response) if response.status().as_u16() == 200 => {
            let json_response = response
                .headers()
                .get("Content-Type")
                .and_then(|value| value.to_str().ok())
                .and_then(|value| value.split(';').next())
                .is_some_and(|value| value.trim().eq_ignore_ascii_case("application/json"));
            if !json_response {
                return Err("Dotted did not return JSON.".to_string());
            }
            response
                .body_mut()
                .read_to_string()
                .map(Some)
                .map_err(|_| "Could not read Dotted's response.".to_string())
        }
        Ok(response) if response.status().as_u16() == 204 => Ok(None),
        Ok(response) => Err(format!(
            "Dotted returned HTTP {} for {path}.",
            response.status().as_u16()
        )),
        Err(ureq::Error::StatusCode(401)) => Err("Dotted rejected the access code.".to_string()),
        Err(ureq::Error::StatusCode(status)) => {
            Err(format!("Dotted returned HTTP {status} for {path}."))
        }
        Err(_) => Err("Could not reach Dotted. Check DOTTED_URL and the connection.".to_string()),
    }
}

pub(crate) fn server_origin(raw_url: &str) -> Result<String, String> {
    let url = raw_url
        .parse::<ureq::http::Uri>()
        .map_err(|_| "DOTTED_URL must be a server URL.".to_string())?;
    let scheme = url.scheme_str().unwrap_or_default();
    let host = url.host().ok_or("DOTTED_URL must include a host.")?;
    let authority = url.authority().ok_or("DOTTED_URL must include a host.")?;

    if authority.as_str().contains('@')
        || !matches!(
            url.path_and_query().map(|value| value.as_str()),
            None | Some("/")
        )
    {
        return Err(
            "DOTTED_URL must contain only a server origin, without a path or credentials.".into(),
        );
    }

    let local = matches!(host, "localhost" | "127.0.0.1" | "[::1]");
    if scheme != "https" && !(scheme == "http" && local) {
        return Err("DOTTED_URL must use HTTPS; HTTP is allowed only for localhost.".into());
    }

    Ok(format!("{scheme}://{authority}"))
}

pub(crate) fn validate_token(token: &str) -> Result<(), String> {
    if token.starts_with("dj_")
        && token.len() == 27
        && token[3..].bytes().all(|byte| byte.is_ascii_alphanumeric())
    {
        Ok(())
    } else {
        Err("DOTTED_TOKEN must be a Dotted access code (dj_...).".into())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{Read, Write};
    use std::net::TcpListener;
    use std::thread;

    const TEST_TOKEN: &str = "dj_AAAAAAAAAAAAAAAAAAAAAAAA";

    fn serve_once(status: &str) -> (String, thread::JoinHandle<String>) {
        serve_once_with_type(status, "application/json")
    }

    fn serve_once_with_type(
        status: &str,
        content_type: &str,
    ) -> (String, thread::JoinHandle<String>) {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let url = format!("http://{}", listener.local_addr().unwrap());
        let status = status.to_string();
        let content_type = content_type.to_string();
        let handle = thread::spawn(move || {
            let (mut stream, _) = listener.accept().unwrap();
            stream
                .set_read_timeout(Some(Duration::from_secs(3)))
                .unwrap();
            let mut request = Vec::new();
            let mut buffer = [0_u8; 1024];
            while !request.ends_with(b"\r\n\r\n") {
                let size = stream.read(&mut buffer).unwrap();
                if size == 0 {
                    break;
                }
                request.extend_from_slice(&buffer[..size]);
            }
            write!(
                stream,
                "HTTP/1.1 {status}\r\nContent-Type: {content_type}\r\nContent-Length: 2\r\nConnection: close\r\n\r\n[]"
            )
            .unwrap();
            String::from_utf8(request).unwrap()
        });
        (url, handle)
    }

    #[test]
    fn accepts_https_and_local_http_origins() {
        assert_eq!(
            server_origin("https://dotted.example.com").unwrap(),
            "https://dotted.example.com"
        );
        assert_eq!(
            server_origin("http://localhost:3000/").unwrap(),
            "http://localhost:3000"
        );
    }

    #[test]
    fn rejects_insecure_or_ambiguous_urls() {
        for url in [
            "http://dotted.example.com",
            "https://user:pass@dotted.example.com",
            "https://dotted.example.com/other",
            "https://dotted.example.com/?token=secret",
        ] {
            assert!(server_origin(url).is_err(), "{url}");
        }
    }

    #[test]
    fn rejects_non_access_code_tokens() {
        assert!(validate_token("other-token").is_err());
        assert!(validate_token("dj_bad\nheader").is_err());
    }

    #[test]
    fn sends_bearer_code_only_to_the_json_endpoint() {
        let (url, server) = serve_once("200 OK");
        assert!(check(&url, TEST_TOKEN).is_ok());

        let request = server.join().unwrap();
        assert!(request.starts_with("GET /access_codes.json HTTP/1.1\r\n"));
        let request = request.to_ascii_lowercase();
        assert!(request.contains(&format!(
            "authorization: bearer {}\r\n",
            TEST_TOKEN.to_ascii_lowercase()
        )));
        assert!(request.contains("accept: application/json\r\n"));
    }

    #[test]
    fn reads_bullets_from_the_json_endpoint() {
        let (url, server) = serve_once("200 OK");
        assert_eq!(get_json(&url, TEST_TOKEN, "/bullets.json").unwrap(), "[]");
        let request = server.join().unwrap();
        assert!(request.starts_with("GET /bullets.json HTTP/1.1\r\n"));
    }

    #[test]
    fn encodes_filter_params_and_accepts_end_of_pages() {
        let (url, server) = serve_once("200 OK");
        let query = [("collection", "Work & Ideas"), ("from", "2026-10-01")];
        assert_eq!(
            get_json_with_query(&url, TEST_TOKEN, "/bullets.json", &query).unwrap(),
            Some("[]".into())
        );
        let request = server.join().unwrap();
        assert!(request.starts_with(
            "GET /bullets.json?collection=Work%20%26%20Ideas&from=2026-10-01 HTTP/1.1\r\n"
        ));

        let (url, server) = serve_once("204 No Content");
        assert_eq!(
            get_json_with_query(&url, TEST_TOKEN, "/bullets.json", &[("before", "42")]).unwrap(),
            None
        );
        server.join().unwrap();
    }

    #[test]
    fn reports_rejected_or_redirected_codes_without_echoing_them() {
        for (status, expected_message) in [
            ("401 Unauthorized", "Dotted rejected the access code."),
            ("302 Found", "Dotted returned HTTP 302"),
        ] {
            let (url, server) = serve_once(status);
            let message = check(&url, TEST_TOKEN).unwrap_err();
            assert!(message.contains(expected_message));
            assert!(!message.contains(TEST_TOKEN));
            server.join().unwrap();
        }
    }

    #[test]
    fn rejects_a_success_page_that_is_not_json() {
        let (url, server) = serve_once_with_type("200 OK", "text/html");
        assert_eq!(
            check(&url, TEST_TOKEN).unwrap_err(),
            "Dotted did not return JSON."
        );
        server.join().unwrap();
    }
}

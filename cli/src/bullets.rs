use std::collections::HashSet;

use serde_json::Value;

use crate::{auth, credentials};

#[derive(Debug, Default, PartialEq, Eq)]
pub struct ListOptions {
    from: Option<String>,
    to: Option<String>,
    collection: Option<String>,
    completed: bool,
    all: bool,
}

impl ListOptions {
    pub fn parse(args: &[String]) -> Result<Self, String> {
        let mut options = Self::default();
        let mut index = 0;
        while index < args.len() {
            let flag = args[index].as_str();
            match flag {
                "--from" | "--to" | "--collection" => {
                    let value = args
                        .get(index + 1)
                        .filter(|value| !value.starts_with("--"))
                        .ok_or_else(|| format!("{flag} needs a value."))?;
                    match flag {
                        "--from" => set_once(&mut options.from, value, flag)?,
                        "--to" => set_once(&mut options.to, value, flag)?,
                        _ => set_once(&mut options.collection, value, flag)?,
                    }
                    index += 2;
                }
                "--completed" => {
                    if options.completed {
                        return Err("--completed was supplied more than once.".into());
                    }
                    options.completed = true;
                    index += 1;
                }
                "--all" => {
                    if options.all {
                        return Err("--all was supplied more than once.".into());
                    }
                    options.all = true;
                    index += 1;
                }
                _ => {
                    return Err(format!(
                        "Unknown bullet list option: {flag}. Run 'dotted-cli help'."
                    ));
                }
            }
        }

        for (name, date) in [("--from", &options.from), ("--to", &options.to)] {
            if let Some(date) = date
                && !valid_date(date)
            {
                return Err(format!("{name} must be a valid date in YYYY-MM-DD format."));
            }
        }
        if let (Some(from), Some(to)) = (&options.from, &options.to)
            && from > to
        {
            return Err("--from must be on or before --to.".into());
        }
        if options
            .collection
            .as_ref()
            .is_some_and(|name| name.trim().is_empty())
        {
            return Err("--collection needs a name.".into());
        }
        Ok(options)
    }

    fn query<'a>(&'a self, before: Option<&'a str>) -> Vec<(&'a str, &'a str)> {
        let mut query = Vec::new();
        if let Some(from) = &self.from {
            query.push(("from", from.as_str()));
        }
        if let Some(to) = &self.to {
            query.push(("to", to.as_str()));
        }
        if let Some(collection) = &self.collection {
            query.push(("collection", collection.as_str()));
        }
        if self.completed {
            query.push(("completed", "true"));
        }
        if let Some(before) = before {
            query.push(("before", before));
        }
        query
    }
}

pub fn list(options: &ListOptions) -> Result<String, String> {
    let (url, token) = credentials::current()?;
    list_with_fetch(options, |query| {
        auth::get_json_with_query(&url, &token, "/bullets.json", query)
    })
}

fn list_with_fetch(
    options: &ListOptions,
    mut fetch: impl FnMut(&[(&str, &str)]) -> Result<Option<String>, String>,
) -> Result<String, String> {
    let mut pages = Vec::new();
    let mut before = None;
    let mut seen_cursors = HashSet::new();

    loop {
        let query = options.query(before.as_deref());
        let Some(json) = fetch(&query)? else {
            break;
        };
        let page: Vec<Value> = serde_json::from_str(&json)
            .map_err(|_| "Dotted returned an invalid bullet list.".to_string())?;
        if page.is_empty() {
            break;
        }

        let next_cursor = if options.all {
            let id = page[0]
                .get("id")
                .and_then(Value::as_u64)
                .ok_or("Dotted returned a bullet without a numeric ID.")?;
            if !seen_cursors.insert(id) {
                return Err("Dotted repeated a bullet page; stopped pagination.".into());
            }
            Some(id.to_string())
        } else {
            None
        };
        pages.push(page);
        if !options.all {
            break;
        }
        before = next_cursor;
    }

    format_pages(pages)
}

fn format_pages(pages: Vec<Vec<Value>>) -> Result<String, String> {
    let bullets: Vec<Value> = pages.into_iter().rev().flatten().collect();
    serde_json::to_string_pretty(&bullets)
        .map_err(|_| "Could not format Dotted's bullet list.".to_string())
}

fn set_once(slot: &mut Option<String>, value: &str, flag: &str) -> Result<(), String> {
    if slot.is_some() {
        return Err(format!("{flag} was supplied more than once."));
    }
    *slot = Some(value.to_string());
    Ok(())
}

fn valid_date(date: &str) -> bool {
    let bytes = date.as_bytes();
    if bytes.len() != 10
        || bytes[4] != b'-'
        || bytes[7] != b'-'
        || !bytes
            .iter()
            .enumerate()
            .all(|(i, byte)| i == 4 || i == 7 || byte.is_ascii_digit())
    {
        return false;
    }
    let year: u32 = date[..4].parse().unwrap();
    let month: u32 = date[5..7].parse().unwrap();
    let day: u32 = date[8..].parse().unwrap();
    if year == 0 || !(1..=12).contains(&month) {
        return false;
    }
    let leap = year.is_multiple_of(4) && (!year.is_multiple_of(100) || year.is_multiple_of(400));
    let days = match month {
        2 if leap => 29,
        2 => 28,
        4 | 6 | 9 | 11 => 30,
        _ => 31,
    };
    (1..=days).contains(&day)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_filters_and_builds_the_same_query_for_every_page() {
        let args = [
            "--from",
            "2024-02-29",
            "--to",
            "2024-03-01",
            "--collection",
            "Work & Ideas",
            "--completed",
            "--all",
        ]
        .map(String::from);
        let options = ListOptions::parse(&args).unwrap();
        assert_eq!(
            options.query(Some("42")),
            vec![
                ("from", "2024-02-29"),
                ("to", "2024-03-01"),
                ("collection", "Work & Ideas"),
                ("completed", "true"),
                ("before", "42")
            ]
        );
    }

    #[test]
    fn rejects_invalid_dates_ranges_and_options() {
        for args in [
            vec!["--from", "2026-02-29"],
            vec!["--from", "2026-10-14", "--to", "2026-10-13"],
            vec!["--collection", "  "],
            vec!["--from"],
            vec!["--unknown"],
            vec!["--all", "--all"],
        ] {
            assert!(
                ListOptions::parse(&args.into_iter().map(String::from).collect::<Vec<_>>())
                    .is_err()
            );
        }
    }

    #[test]
    fn combines_older_pages_first_and_keeps_json_readable() {
        let latest = serde_json::from_str(r#"[{"id":3,"body":"Third\nline"},{"id":4}]"#).unwrap();
        let older = serde_json::from_str(r#"[{"id":1},{"id":2}]"#).unwrap();
        let output = format_pages(vec![latest, older]).unwrap();
        let ids: Vec<u64> = serde_json::from_str::<Vec<Value>>(&output)
            .unwrap()
            .iter()
            .map(|bullet| bullet["id"].as_u64().unwrap())
            .collect();
        assert_eq!(ids, [1, 2, 3, 4]);
        assert!(output.contains("\n    \"body\": \"Third\\nline\""));
    }

    #[test]
    fn all_follows_cursors_and_retains_filters() {
        let args = ["--collection", "Work & Ideas", "--all"].map(String::from);
        let options = ListOptions::parse(&args).unwrap();
        let mut requests = Vec::new();
        let output = list_with_fetch(&options, |query| {
            requests.push(
                query
                    .iter()
                    .map(|(key, value)| (key.to_string(), value.to_string()))
                    .collect::<Vec<_>>(),
            );
            Ok(match requests.len() {
                1 => Some(r#"[{"id":3},{"id":4}]"#.into()),
                2 => Some(r#"[{"id":1},{"id":2}]"#.into()),
                _ => None,
            })
        })
        .unwrap();
        let ids: Vec<u64> = serde_json::from_str::<Vec<Value>>(&output)
            .unwrap()
            .iter()
            .map(|bullet| bullet["id"].as_u64().unwrap())
            .collect();
        assert_eq!(ids, [1, 2, 3, 4]);
        assert_eq!(
            requests,
            [
                vec![("collection".into(), "Work & Ideas".into())],
                vec![
                    ("collection".into(), "Work & Ideas".into()),
                    ("before".into(), "3".into())
                ],
                vec![
                    ("collection".into(), "Work & Ideas".into()),
                    ("before".into(), "1".into())
                ],
            ]
        );
    }
}

//! Normalized search hits. Implementations live outside this crate.

use std::collections::BTreeSet;

/// One query sent to a provider. The router chooses the engine; the model
/// does not.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SearchRequest {
    pub query: String,
    pub max_results: u32,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SearchHit {
    pub url: String,
    pub title: String,
    pub snippet: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SearchResponse {
    pub engine_id: String,
    pub hits: Vec<SearchHit>,
}

#[derive(Debug, PartialEq, Eq)]
pub enum SearchError {
    Unavailable(&'static str),
    InvalidQuery,
}

impl std::fmt::Display for SearchError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Unavailable(id) => write!(f, "search engine {id} is unavailable"),
            Self::InvalidQuery => write!(f, "search query is empty"),
        }
    }
}

impl std::error::Error for SearchError {}

/// Replaceable search provider. Google is one implementation, not the engine.
pub trait SearchEngine: Send + Sync {
    fn id(&self) -> &'static str;
    fn search(&self, request: &SearchRequest) -> Result<SearchResponse, SearchError>;
}

/// Collapse tracking variants into one source key.
///
/// `https://www.example.com/article?utm_source=x` and
/// `http://example.com/article/` become `https://example.com/article`.
pub fn canonicalize_url(raw: &str) -> String {
    let trimmed = raw.trim();
    let without_scheme = trimmed
        .strip_prefix("https://")
        .or_else(|| trimmed.strip_prefix("http://"))
        .unwrap_or(trimmed);
    let (host_path, query) = without_scheme
        .split_once('?')
        .unwrap_or((without_scheme, ""));
    let host_path = host_path.trim_end_matches('/');
    let host_path = host_path.strip_prefix("www.").unwrap_or(host_path);
    let (host, path) = host_path.split_once('/').unwrap_or((host_path, ""));
    let host = host.to_ascii_lowercase();
    let host_path = if path.is_empty() {
        host
    } else {
        format!("{host}/{path}")
    };
    let kept: Vec<&str> = query
        .split('&')
        .filter(|pair| {
            let key = pair.split('=').next().unwrap_or("");
            !key.starts_with("utm") && key != "fbclid" && !key.is_empty()
        })
        .collect();
    if kept.is_empty() {
        format!("https://{host_path}")
    } else {
        format!("https://{host_path}?{}", kept.join("&"))
    }
}

/// Drop hits that share a canonical URL, first engine wins.
pub fn dedupe_hits(hits: Vec<SearchHit>) -> Vec<SearchHit> {
    let mut seen = BTreeSet::new();
    let mut out = Vec::new();
    for hit in hits {
        let key = canonicalize_url(&hit.url);
        if seen.insert(key) {
            out.push(hit);
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    struct FakeEngine {
        id: &'static str,
        url: &'static str,
    }

    impl SearchEngine for FakeEngine {
        fn id(&self) -> &'static str {
            self.id
        }

        fn search(&self, request: &SearchRequest) -> Result<SearchResponse, SearchError> {
            if request.query.trim().is_empty() {
                return Err(SearchError::InvalidQuery);
            }
            Ok(SearchResponse {
                engine_id: self.id.to_string(),
                hits: vec![SearchHit {
                    url: self.url.to_string(),
                    title: request.query.clone(),
                    snippet: "fixture".to_string(),
                }],
            })
        }
    }

    #[test]
    fn engines_are_selected_by_id_not_by_google() {
        let engines: [&dyn SearchEngine; 2] = [
            &FakeEngine {
                id: "searxng",
                url: "https://example.test/a",
            },
            &FakeEngine {
                id: "arxiv",
                url: "https://arxiv.org/abs/0000",
            },
        ];
        let request = SearchRequest {
            query: "offline llm".to_string(),
            max_results: 3,
        };
        let ids: Vec<_> = engines
            .iter()
            .map(|engine| engine.search(&request).unwrap().engine_id)
            .collect();
        assert_eq!(ids, ["searxng", "arxiv"]);
    }

    #[test]
    fn tracking_variants_collapse_to_one_source() {
        let hits = vec![
            SearchHit {
                url: "https://www.example.com/article?utm_source=google".into(),
                title: "A".into(),
                snippet: String::new(),
            },
            SearchHit {
                url: "http://example.com/article/".into(),
                title: "B".into(),
                snippet: String::new(),
            },
            SearchHit {
                url: "https://arxiv.org/abs/1234".into(),
                title: "C".into(),
                snippet: String::new(),
            },
        ];
        let deduped = dedupe_hits(hits);
        assert_eq!(deduped.len(), 2);
        assert_eq!(
            canonicalize_url("https://www.example.com/article?utm_source=google"),
            "https://example.com/article"
        );
        assert_eq!(
            canonicalize_url("https://en.wikipedia.org/wiki/Large_language_model"),
            "https://en.wikipedia.org/wiki/Large_language_model"
        );
    }
}

//! User-facing privacy profiles. These select engines; the model does not.

use super::request::SearchPolicy;

/// PRIVATE / BALANCED / CLOUD. Google is never implied by any of them.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PrivacyProfile {
    Private,
    Balanced,
    Cloud,
}

impl PrivacyProfile {
    pub fn search_policy(self) -> SearchPolicy {
        match self {
            Self::Private => SearchPolicy::PrivacyFirst,
            Self::Balanced => SearchPolicy::Balanced,
            Self::Cloud => SearchPolicy::MaximumQuality,
        }
    }

    /// Engine ids this profile may use. SearXNG is allowed for Private when a
    /// host later injects it; we do not ship a Google adapter here.
    pub fn engine_ids(self) -> &'static [&'static str] {
        match self {
            Self::Private => &["wikipedia", "searxng"],
            Self::Balanced | Self::Cloud => &["wikipedia", "arxiv", "semantic_scholar"],
        }
    }

    pub fn allows(self, engine_id: &str) -> bool {
        self.engine_ids().contains(&engine_id)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn commercial() -> [&'static str; 4] {
        ["google", "bing", "tavily", "duckduckgo"]
    }

    #[test]
    fn private_is_local_plus_searxng_and_never_commercial() {
        let ids = PrivacyProfile::Private.engine_ids();
        assert!(ids.contains(&"wikipedia"));
        assert!(ids.contains(&"searxng"));
        assert!(!ids.contains(&"semantic_scholar"));
        for id in commercial() {
            assert!(
                !PrivacyProfile::Private.allows(id),
                "{id} leaked into Private"
            );
        }
        assert_eq!(
            PrivacyProfile::Private.search_policy(),
            SearchPolicy::PrivacyFirst
        );
    }

    #[test]
    fn balanced_and_cloud_never_imply_google() {
        for profile in [PrivacyProfile::Balanced, PrivacyProfile::Cloud] {
            assert!(profile.allows("wikipedia"));
            assert!(profile.allows("arxiv"));
            assert!(profile.allows("semantic_scholar"));
            for id in commercial() {
                assert!(!profile.allows(id), "{id} leaked into {profile:?}");
            }
        }
        assert_eq!(
            PrivacyProfile::Cloud.search_policy(),
            SearchPolicy::MaximumQuality
        );
    }
}

//! Claim / evidence / source graph. Synthesis may not invent citations.

use std::collections::BTreeMap;

use crate::research::document::{SourceClass, SourceKind};

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct ClaimId(pub String);

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct EvidenceId(pub String);

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct SourceId(pub String);

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ClaimStatus {
    Supported,
    Contradicted,
    PartiallySupported,
    Unverified,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SourceType {
    Official,
    Paper,
    Benchmark,
    TechnicalArticle,
    Community,
    Unknown,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Claim {
    pub id: ClaimId,
    pub text: String,
    pub confidence: f32,
    pub status: ClaimStatus,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Evidence {
    pub id: EvidenceId,
    pub claim_id: ClaimId,
    pub source_id: SourceId,
    pub excerpt: String,
    pub relevance: f32,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Source {
    pub id: SourceId,
    pub url: String,
    pub title: String,
    pub source_type: SourceType,
    pub class: SourceClass,
    pub kind: SourceKind,
    pub credibility: f32,
    pub published_at: Option<String>,
    pub modified_at: Option<String>,
    pub retrieved_at: String,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct EvidenceGraph {
    claims: BTreeMap<ClaimId, Claim>,
    evidence: BTreeMap<EvidenceId, Evidence>,
    sources: BTreeMap<SourceId, Source>,
}

impl EvidenceGraph {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn upsert_source(&mut self, source: Source) {
        self.sources.insert(source.id.clone(), source);
    }

    pub fn upsert_claim(&mut self, claim: Claim) {
        self.claims.insert(claim.id.clone(), claim);
    }

    pub fn attach_evidence(&mut self, evidence: Evidence) -> Result<(), &'static str> {
        if !self.claims.contains_key(&evidence.claim_id) {
            return Err("evidence refers to an unknown claim");
        }
        if !self.sources.contains_key(&evidence.source_id) {
            return Err("evidence refers to an unknown source");
        }
        let claim_id = evidence.claim_id.clone();
        self.evidence.insert(evidence.id.clone(), evidence);
        if let Some(claim) = self.claims.get_mut(&claim_id) {
            if claim.status == ClaimStatus::Unverified {
                claim.status = ClaimStatus::PartiallySupported;
            }
        }
        Ok(())
    }

    pub fn mark_contradicted(
        &mut self,
        left: &ClaimId,
        right: &ClaimId,
    ) -> Result<(), &'static str> {
        if !self.claims.contains_key(left) || !self.claims.contains_key(right) {
            return Err("unknown claim");
        }
        self.claims.get_mut(left).unwrap().status = ClaimStatus::Contradicted;
        self.claims.get_mut(right).unwrap().status = ClaimStatus::Contradicted;
        Ok(())
    }

    pub fn unsupported_claims(&self) -> Vec<&Claim> {
        self.claims
            .values()
            .filter(|claim| {
                claim.status == ClaimStatus::Unverified
                    || !self.evidence.values().any(|item| item.claim_id == claim.id)
            })
            .collect()
    }

    pub fn claim_count(&self) -> usize {
        self.claims.len()
    }
}

/// A citation is valid only when the excerpt actually appears in acquired text.
pub fn excerpt_in_source(source_text: &str, excerpt: &str) -> bool {
    let needle = excerpt.trim().to_ascii_lowercase();
    !needle.is_empty() && source_text.to_ascii_lowercase().contains(&needle)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn source(id: &str) -> Source {
        Source {
            id: SourceId(id.to_string()),
            url: format!("https://example.test/{id}"),
            title: id.to_string(),
            source_type: SourceType::Paper,
            class: SourceClass::Primary,
            kind: SourceKind::Academic,
            credibility: 0.8,
            published_at: None,
            modified_at: None,
            retrieved_at: "2026-08-22T00:00:00Z".into(),
        }
    }

    #[test]
    fn a_claim_without_evidence_stays_unverified() {
        let mut graph = EvidenceGraph::new();
        graph.upsert_claim(Claim {
            id: ClaimId("c1".into()),
            text: "Model X is 40% faster".into(),
            confidence: 0.0,
            status: ClaimStatus::Unverified,
        });
        assert_eq!(graph.unsupported_claims().len(), 1);
    }

    #[test]
    fn evidence_must_point_at_a_real_source() {
        let mut graph = EvidenceGraph::new();
        graph.upsert_claim(Claim {
            id: ClaimId("c1".into()),
            text: "8 GB RAM".into(),
            confidence: 0.0,
            status: ClaimStatus::Unverified,
        });
        let err = graph
            .attach_evidence(Evidence {
                id: EvidenceId("e1".into()),
                claim_id: ClaimId("c1".into()),
                source_id: SourceId("missing".into()),
                excerpt: "uses 8 GB".into(),
                relevance: 1.0,
            })
            .expect_err("no dangling citations");
        assert_eq!(err, "evidence refers to an unknown source");
    }

    #[test]
    fn conflicting_claims_are_marked_not_silently_picked() {
        let mut graph = EvidenceGraph::new();
        graph.upsert_source(source("a"));
        graph.upsert_claim(Claim {
            id: ClaimId("eight".into()),
            text: "8 GB RAM".into(),
            confidence: 0.4,
            status: ClaimStatus::Unverified,
        });
        graph.upsert_claim(Claim {
            id: ClaimId("five".into()),
            text: "5 GB RAM".into(),
            confidence: 0.4,
            status: ClaimStatus::Unverified,
        });
        graph
            .mark_contradicted(&ClaimId("eight".into()), &ClaimId("five".into()))
            .unwrap();
        assert_eq!(
            graph.claims[&ClaimId("eight".into())].status,
            ClaimStatus::Contradicted
        );
        assert_eq!(
            graph.claims[&ClaimId("five".into())].status,
            ClaimStatus::Contradicted
        );
    }

    #[test]
    fn a_citation_is_invalid_when_the_excerpt_is_not_in_the_source() {
        let page = "Qwen is a family of large language models from Alibaba.";
        assert!(excerpt_in_source(page, "family of large language models"));
        assert!(!excerpt_in_source(page, "Qwen uses 2 GB of RAM."));
    }
}

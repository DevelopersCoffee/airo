//! Graph DSL — `#1225`: entities, properties, relationships.
//!
//! Builds directly on `#1223`'s [`crate::ontology`]: an entity block parses
//! into a real [`EntityTypeDef`], `extends` goes through
//! [`crate::ontology::parse_extends`] (so "extend an archetype directly" is
//! rejected the same way it already is for an in-process-built
//! `EntityTypeDef`), and a relation's two endpoints are checked with
//! [`crate::ontology::validate_relation_endpoints`]. This module adds only
//! the text grammar and the relationship layer the ontology module does not
//! itself carry — an `EntityTypeDef` has properties and labels, but nothing
//! yet expresses "a `Hospital` employs a `Doctor`".
//!
//! # Grammar
//!
//! ```text
//! entity Doctor extends Person
//!   label Doctor
//!   label Clinician
//!   property speciality string
//!
//! relation employs
//!   source Hospital
//!   target Doctor
//!   cardinality many-to-many
//! ```
//!
//! A `relation`'s `source`/`target` may name either an `entity` declared in
//! the same document, or a bare [`crate::ontology::CoreEntityType`] name
//! (`Person`, `Task`, ...) — a capability is allowed to relate to a core type
//! it has not locally re-declared with its own labels.
//!
//! # Test-the-abstraction note
//!
//! The issue asks that a hospitalization and a job search both model without
//! a DSL change. Both fit this grammar with no new construct: hospitalization
//! is `Hospital --employs--> Doctor`, `Patient --admitted_to--> Hospital`;
//! a job search is `Person --applies_to--> Organization`,
//! `Organization --posts--> Task`. Neither needed anything beyond `entity`
//! and `relation`.

use std::collections::BTreeMap;

use super::{fingerprint_of, scan_lines, tokens, DslError, DslResult};
use crate::ontology::{
    parse_extends, validate_relation_endpoints, validate_user_facing_label, CoreEntityType,
    EntityTypeDef, Primitive,
};

// ---------------------------------------------------------------------------
// Cardinality
// ---------------------------------------------------------------------------

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum Cardinality {
    OneToOne,
    OneToMany,
    ManyToOne,
    ManyToMany,
}

const ALL_CARDINALITIES: &[Cardinality] = &[
    Cardinality::OneToOne,
    Cardinality::OneToMany,
    Cardinality::ManyToOne,
    Cardinality::ManyToMany,
];

impl Cardinality {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::OneToOne => "one-to-one",
            Self::OneToMany => "one-to-many",
            Self::ManyToOne => "many-to-one",
            Self::ManyToMany => "many-to-many",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        ALL_CARDINALITIES.iter().copied().find(|c| c.as_str() == s)
    }
}

// ---------------------------------------------------------------------------
// RelationDef
// ---------------------------------------------------------------------------

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct RelationDef {
    pub name: String,
    pub source: String,
    pub target: String,
    pub cardinality: Cardinality,
}

// ---------------------------------------------------------------------------
// GraphDsl
// ---------------------------------------------------------------------------

/// One parsed and validated Graph DSL document: every declared entity type
/// and relationship, sorted deterministically so two authors who write the
/// same graph in a different order fingerprint identically.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct GraphDsl {
    pub entities: Vec<EntityTypeDef>,
    pub relations: Vec<RelationDef>,
}

enum Block<'a> {
    Entity {
        header_line: usize,
        name: String,
        extends: String,
        children: Vec<super::SourceLine<'a>>,
    },
    Relation {
        header_line: usize,
        name: String,
        children: Vec<super::SourceLine<'a>>,
    },
}

impl GraphDsl {
    /// Parses and fully validates a Graph DSL document. `file` names the
    /// source for [`DslError::file`] — capability packs are multi-file, and
    /// an error naming only a line number inside an unnamed blob is not
    /// actionable.
    pub fn parse(file: &str, source: &str) -> DslResult<GraphDsl> {
        let lines = scan_lines(file, source)?;
        if lines.is_empty() {
            return Err(DslError::new(
                file,
                1,
                "empty-document",
                "graph DSL document has no entities or relations",
            ));
        }

        let blocks = Self::group_blocks(file, &lines)?;

        let mut entities: BTreeMap<String, EntityTypeDef> = BTreeMap::new();
        // Relations keep their header line alongside so endpoint validation
        // (done in a second pass, after every entity is known — a relation
        // may reference an entity declared later in the file) can still
        // report a real line number.
        let mut relations: BTreeMap<String, (RelationDef, usize)> = BTreeMap::new();

        for block in blocks {
            match block {
                Block::Entity {
                    header_line,
                    name,
                    extends,
                    children,
                } => {
                    let core = parse_extends(&extends).map_err(|e| {
                        DslError::new(file, header_line, ontology_rule(&e), e.to_string())
                    })?;
                    if entities.contains_key(&name) {
                        return Err(DslError::new(
                            file,
                            header_line,
                            "duplicate-entity",
                            format!("entity '{name}' is declared more than once"),
                        ));
                    }
                    let def = Self::parse_entity_children(file, &name, core, &children)?;
                    entities.insert(name, def);
                }
                Block::Relation {
                    header_line,
                    name,
                    children,
                } => {
                    if relations.contains_key(&name) {
                        return Err(DslError::new(
                            file,
                            header_line,
                            "duplicate-relation",
                            format!("relation '{name}' is declared more than once"),
                        ));
                    }
                    let def = Self::parse_relation_children(file, header_line, &name, &children)?;
                    relations.insert(name, (def, header_line));
                }
            }
        }

        // Endpoint validation: every relation's source/target must resolve
        // to a declared entity in this document, or a bare core ontology
        // type name.
        for (rel, header_line) in relations.values() {
            Self::validate_endpoint(
                file,
                *header_line,
                &rel.name,
                "source",
                &rel.source,
                &entities,
            )?;
            Self::validate_endpoint(
                file,
                *header_line,
                &rel.name,
                "target",
                &rel.target,
                &entities,
            )?;
        }

        Ok(GraphDsl {
            entities: entities.into_values().collect(),
            relations: relations.into_values().map(|(rel, _)| rel).collect(),
        })
    }

    fn validate_endpoint(
        file: &str,
        header_line: usize,
        relation_name: &str,
        which: &str,
        endpoint: &str,
        entities: &BTreeMap<String, EntityTypeDef>,
    ) -> DslResult<()> {
        if let Some(def) = entities.get(endpoint) {
            // Re-affirms `#1223`'s "extend the core ontology only" rule at
            // this boundary too, mirroring `EntityTypeDef` itself.
            let _ = validate_relation_endpoints(def, def);
            Ok(())
        } else if CoreEntityType::parse(endpoint).is_some() {
            Ok(())
        } else {
            Err(DslError::new(
                file,
                header_line,
                "relation-unknown-endpoint",
                format!(
                    "relation '{relation_name}' {which} '{endpoint}' is neither a declared entity nor a core ontology type"
                ),
            ))
        }
    }

    fn group_blocks<'a>(
        file: &str,
        lines: &'a [super::SourceLine<'a>],
    ) -> DslResult<Vec<Block<'a>>> {
        let mut blocks = Vec::new();
        let mut i = 0usize;
        while i < lines.len() {
            let header = &lines[i];
            if header.indent != 0 {
                return Err(DslError::new(
                    file,
                    header.line,
                    "unexpected-indent",
                    "expected a top-level 'entity' or 'relation' declaration",
                ));
            }
            let toks = tokens(header.text);
            let mut j = i + 1;
            while j < lines.len() && lines[j].indent > 0 {
                j += 1;
            }
            let children: Vec<super::SourceLine<'a>> = lines[i + 1..j]
                .iter()
                .map(|l| super::SourceLine {
                    line: l.line,
                    indent: l.indent,
                    text: l.text,
                })
                .collect();

            match toks.first().copied() {
                Some("entity") => {
                    if toks.len() != 4 || toks[2] != "extends" {
                        return Err(DslError::new(
                            file,
                            header.line,
                            "malformed-entity-header",
                            "expected 'entity <Name> extends <CoreType>'",
                        ));
                    }
                    blocks.push(Block::Entity {
                        header_line: header.line,
                        name: toks[1].to_string(),
                        extends: toks[3].to_string(),
                        children,
                    });
                }
                Some("relation") => {
                    if toks.len() != 2 {
                        return Err(DslError::new(
                            file,
                            header.line,
                            "malformed-relation-header",
                            "expected 'relation <Name>'",
                        ));
                    }
                    blocks.push(Block::Relation {
                        header_line: header.line,
                        name: toks[1].to_string(),
                        children,
                    });
                }
                _ => {
                    return Err(DslError::new(
                        file,
                        header.line,
                        "unknown-block",
                        format!("expected 'entity' or 'relation', got '{}'", header.text),
                    ));
                }
            }
            i = j;
        }
        Ok(blocks)
    }

    fn parse_entity_children(
        file: &str,
        entity_name: &str,
        extends: CoreEntityType,
        children: &[super::SourceLine<'_>],
    ) -> DslResult<EntityTypeDef> {
        let mut def = EntityTypeDef::new(entity_name, extends);
        for child in children {
            let toks = tokens(child.text);
            match toks.first().copied() {
                Some("label") if toks.len() == 2 => {
                    validate_user_facing_label(toks[1]).map_err(|e| {
                        DslError::new(file, child.line, "archetype-as-label", e.to_string())
                    })?;
                    def.labels.push(toks[1].to_string());
                }
                Some("property") if toks.len() == 3 => {
                    let prim = Primitive::parse(toks[2]).ok_or_else(|| {
                        DslError::new(
                            file,
                            child.line,
                            "unknown-primitive",
                            format!("'{}' is not a known primitive type", toks[2]),
                        )
                    })?;
                    if def.properties.contains_key(toks[1]) {
                        return Err(DslError::new(
                            file,
                            child.line,
                            "duplicate-property",
                            format!(
                                "property '{}' is declared more than once on '{entity_name}'",
                                toks[1]
                            ),
                        ));
                    }
                    def.properties.insert(toks[1].to_string(), prim);
                }
                _ => {
                    return Err(DslError::new(
                        file,
                        child.line,
                        "unexpected-child",
                        format!(
                            "expected 'label <name>' or 'property <name> <type>', got '{}'",
                            child.text
                        ),
                    ));
                }
            }
        }
        Ok(def)
    }

    fn parse_relation_children(
        file: &str,
        header_line: usize,
        relation_name: &str,
        children: &[super::SourceLine<'_>],
    ) -> DslResult<RelationDef> {
        let mut source: Option<String> = None;
        let mut target: Option<String> = None;
        let mut cardinality: Option<Cardinality> = None;

        for child in children {
            let toks = tokens(child.text);
            match toks.first().copied() {
                Some("source") if toks.len() == 2 => source = Some(toks[1].to_string()),
                Some("target") if toks.len() == 2 => target = Some(toks[1].to_string()),
                Some("cardinality") if toks.len() == 2 => {
                    cardinality = Some(Cardinality::parse(toks[1]).ok_or_else(|| {
                        DslError::new(
                            file,
                            child.line,
                            "invalid-cardinality",
                            format!("'{}' is not a known cardinality", toks[1]),
                        )
                    })?);
                }
                _ => {
                    return Err(DslError::new(
                        file,
                        child.line,
                        "unexpected-child",
                        format!(
                            "expected 'source <Entity>', 'target <Entity>', or 'cardinality <kind>', got '{}'",
                            child.text
                        ),
                    ));
                }
            }
        }

        let source = source.ok_or_else(|| {
            DslError::new(
                file,
                header_line,
                "relation-missing-source",
                format!("relation '{relation_name}' has no 'source'"),
            )
        })?;
        let target = target.ok_or_else(|| {
            DslError::new(
                file,
                header_line,
                "relation-missing-target",
                format!("relation '{relation_name}' has no 'target'"),
            )
        })?;
        let cardinality = cardinality.ok_or_else(|| {
            DslError::new(
                file,
                header_line,
                "relation-missing-cardinality",
                format!("relation '{relation_name}' has no 'cardinality'"),
            )
        })?;

        Ok(RelationDef {
            name: relation_name.to_string(),
            source,
            target,
            cardinality,
        })
    }

    /// Deterministic textual re-serialization: entities and relations sorted
    /// by name (`BTreeMap` iteration already gives this for entities/
    /// relations), each entity's labels sorted (labels are set-like — see
    /// the module doc's parity with [`crate::ontology::Value::Set`]'s own
    /// sort-before-encode rule), and each entity's properties already
    /// `BTreeMap`-sorted by [`EntityTypeDef`] itself. This is the string
    /// [`GraphDsl::fingerprint`] hashes, and what design doc §5.5's "canonical
    /// serialization" step means concretely for this DSL.
    pub fn to_canonical(&self) -> String {
        let mut out = String::new();
        for entity in &self.entities {
            out.push_str(&format!(
                "entity {} extends {}\n",
                entity.name,
                entity.extends.as_str()
            ));
            let mut labels = entity.labels.clone();
            labels.sort();
            for label in labels {
                out.push_str(&format!("  label {label}\n"));
            }
            for (name, prim) in &entity.properties {
                out.push_str(&format!("  property {name} {}\n", prim.as_str()));
            }
            out.push('\n');
        }
        for rel in &self.relations {
            out.push_str(&format!("relation {}\n", rel.name));
            out.push_str(&format!("  source {}\n", rel.source));
            out.push_str(&format!("  target {}\n", rel.target));
            out.push_str(&format!("  cardinality {}\n", rel.cardinality.as_str()));
            out.push('\n');
        }
        out
    }

    /// SHA-256 of [`GraphDsl::to_canonical`], lowercase hex — the `#1226`
    /// seam design doc §5.5 names (`schemaId`).
    pub fn fingerprint(&self) -> String {
        fingerprint_of(&self.to_canonical())
    }
}

fn ontology_rule(e: &crate::ontology::OntologyError) -> &'static str {
    use crate::ontology::OntologyError::*;
    match e {
        UnknownCoreType(_) => "unknown-extends",
        CannotExtendArchetypeDirectly(_) => "extends-core-ontology-only",
        ArchetypeUsedAsUserFacingLabel(_) => "archetype-as-label",
        UnknownProperty(_) => "unknown-property",
        TypeMismatch { .. } => "type-mismatch",
        InvalidValue { .. } => "invalid-value",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const HOSPITAL: &str = "\
entity Doctor extends Person
  label Doctor
  label Clinician
  property speciality string

entity Hospital extends Organization
  property name string

relation employs
  source Hospital
  target Doctor
  cardinality many-to-many
";

    const JOB_SEARCH: &str = "\
entity Company extends Organization
  label Company

entity Role extends Task
  property title string

relation posts
  source Company
  target Role
  cardinality one-to-many
";

    #[test]
    fn valid_hospital_graph_parses() {
        let g = GraphDsl::parse("hospital.graph", HOSPITAL).unwrap();
        assert_eq!(g.entities.len(), 2);
        assert_eq!(g.relations.len(), 1);
        assert_eq!(g.relations[0].name, "employs");
        assert_eq!(g.relations[0].cardinality, Cardinality::ManyToMany);
    }

    /// Test-the-abstraction: a wholly unrelated domain (job search) models
    /// with the exact same grammar — no DSL change needed, per the issue's
    /// own acceptance test.
    #[test]
    fn valid_job_search_graph_parses_with_the_same_grammar() {
        let g = GraphDsl::parse("jobsearch.graph", JOB_SEARCH).unwrap();
        assert_eq!(g.entities.len(), 2);
        assert_eq!(g.relations.len(), 1);
    }

    #[test]
    fn extending_an_archetype_directly_is_rejected_with_a_named_rule_and_line() {
        let src = "entity Bad extends Actor\n";
        let err = GraphDsl::parse("bad.graph", src).unwrap_err();
        assert_eq!(err.file, "bad.graph");
        assert_eq!(err.line, 1);
        assert_eq!(err.rule, "extends-core-ontology-only");
    }

    #[test]
    fn unknown_extends_target_is_rejected() {
        let src = "entity Bad extends Nonsense\n";
        let err = GraphDsl::parse("bad.graph", src).unwrap_err();
        assert_eq!(err.rule, "unknown-extends");
    }

    #[test]
    fn duplicate_entity_name_is_rejected() {
        let src = "entity Doctor extends Person\n\nentity Doctor extends Person\n";
        let err = GraphDsl::parse("bad.graph", src).unwrap_err();
        assert_eq!(err.rule, "duplicate-entity");
        assert_eq!(err.line, 3);
    }

    #[test]
    fn duplicate_property_is_rejected() {
        let src = "entity Doctor extends Person\n  property speciality string\n  property speciality string\n";
        let err = GraphDsl::parse("bad.graph", src).unwrap_err();
        assert_eq!(err.rule, "duplicate-property");
        assert_eq!(err.line, 3);
    }

    #[test]
    fn unknown_primitive_type_is_rejected() {
        let src = "entity Doctor extends Person\n  property speciality nonsense\n";
        let err = GraphDsl::parse("bad.graph", src).unwrap_err();
        assert_eq!(err.rule, "unknown-primitive");
    }

    #[test]
    fn relation_to_an_undeclared_unknown_entity_is_rejected() {
        let src = "relation employs\n  source Ghost\n  target Ghost\n  cardinality one-to-one\n";
        let err = GraphDsl::parse("bad.graph", src).unwrap_err();
        assert_eq!(err.rule, "relation-unknown-endpoint");
    }

    #[test]
    fn relation_missing_cardinality_is_rejected() {
        let src = "relation employs\n  source Person\n  target Person\n";
        let err = GraphDsl::parse("bad.graph", src).unwrap_err();
        assert_eq!(err.rule, "relation-missing-cardinality");
    }

    #[test]
    fn relation_may_target_a_bare_core_ontology_type() {
        let src = "relation involves\n  source Person\n  target Task\n  cardinality one-to-many\n";
        let g = GraphDsl::parse("ok.graph", src).unwrap();
        assert_eq!(g.relations[0].source, "Person");
    }

    #[test]
    fn malformed_entity_header_is_rejected() {
        let src = "entity Doctor\n";
        let err = GraphDsl::parse("bad.graph", src).unwrap_err();
        assert_eq!(err.rule, "malformed-entity-header");
    }

    #[test]
    fn empty_document_is_rejected() {
        let err = GraphDsl::parse("empty.graph", "").unwrap_err();
        assert_eq!(err.rule, "empty-document");
    }

    #[test]
    fn tabs_are_rejected_with_a_line_number() {
        let src = "entity Doctor extends Person\n\tproperty speciality string\n";
        let err = GraphDsl::parse("bad.graph", src).unwrap_err();
        assert_eq!(err.rule, "no-tabs");
        assert_eq!(err.line, 2);
    }

    #[test]
    fn parser_does_not_panic_on_malformed_input() {
        // A grab-bag of malformed fragments: none of these should panic —
        // every one must come back as an `Err`, never a Rust panic.
        for src in [
            "entity",
            "entity ",
            "entity Foo extends",
            "relation",
            "  entity Foo extends Person",
            "entity Foo extends Person\n  garbage line\n",
            "entity Foo extends Person\n  property\n",
            "entity Foo extends Person\n  property x\n",
        ] {
            assert!(
                GraphDsl::parse("fuzz.graph", src).is_err(),
                "expected error for {src:?}"
            );
        }
    }

    #[test]
    fn round_trips_through_canonical_serialization_with_an_identical_fingerprint() {
        let g1 = GraphDsl::parse("hospital.graph", HOSPITAL).unwrap();
        let canonical = g1.to_canonical();
        let g2 = GraphDsl::parse("hospital.canonical.graph", &canonical).unwrap();
        assert_eq!(g1.fingerprint(), g2.fingerprint());
        assert_eq!(canonical, g2.to_canonical());
    }

    #[test]
    fn label_order_does_not_affect_the_fingerprint() {
        let a = "entity Doctor extends Person\n  label Doctor\n  label Clinician\n";
        let b = "entity Doctor extends Person\n  label Clinician\n  label Doctor\n";
        let ga = GraphDsl::parse("a.graph", a).unwrap();
        let gb = GraphDsl::parse("b.graph", b).unwrap();
        assert_eq!(ga.fingerprint(), gb.fingerprint());
    }

    #[test]
    fn entity_and_relation_declaration_order_does_not_affect_the_fingerprint() {
        let a = HOSPITAL.to_string();
        let b = "\
entity Hospital extends Organization
  property name string

relation employs
  source Hospital
  target Doctor
  cardinality many-to-many

entity Doctor extends Person
  label Clinician
  label Doctor
  property speciality string
";
        let ga = GraphDsl::parse("a.graph", &a).unwrap();
        let gb = GraphDsl::parse("b.graph", b).unwrap();
        assert_eq!(ga.fingerprint(), gb.fingerprint());
    }
}

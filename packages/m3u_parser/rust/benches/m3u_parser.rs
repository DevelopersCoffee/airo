use std::fs;

use m3u_parser::api::m3u::{parse_m3u_channels_with_stats, parse_m3u_entries};
use criterion::{black_box, criterion_group, criterion_main, BenchmarkId, Criterion, Throughput};

fn iptv_org_fixture() -> Option<String> {
    // Reaches the monorepo's shared fixture — fine for a dev-only bench
    // that never ships as part of the published Dart package. From
    // packages/m3u_parser/rust/benches, climb to the repo root. Cargo bench
    // targets are part of `cargo test`'s default target set, so this must
    // degrade gracefully rather than panic: a copy of just this package
    // (without the sibling `iptv-data/` directory — exactly the
    // self-contained-package scenario the ADR's extraction rationale is
    // meant to support) would otherwise fail `cargo test`, not just
    // `cargo bench`.
    let path = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../../iptv-data/fixtures/iptv-org/index.m3u");
    match fs::read_to_string(&path) {
        Ok(content) => Some(content),
        Err(error) => {
            eprintln!(
                "skipping m3u_parser bench: iptv-org fixture not found at {} ({error})",
                path.display()
            );
            None
        }
    }
}

fn bench_m3u_parser(c: &mut Criterion) {
    let Some(fixture) = iptv_org_fixture() else {
        return;
    };
    let byte_count = fixture.len() as u64;
    let channel_count = parse_m3u_entries(fixture.clone()).len();

    let mut group = c.benchmark_group("m3u_parser");
    group.throughput(Throughput::Bytes(byte_count));
    group.bench_with_input(
        BenchmarkId::new("iptv_org_index", channel_count),
        &fixture,
        |b, content| {
            b.iter(|| {
                let entries = parse_m3u_entries(black_box(content.clone()));
                black_box(entries.len())
            });
        },
    );
    group.bench_with_input(
        BenchmarkId::new("iptv_org_index_channels", channel_count),
        &fixture,
        |b, content| {
            b.iter(|| {
                let result = parse_m3u_channels_with_stats(black_box(content.clone()));
                black_box(result.channels.len())
            });
        },
    );
    group.finish();
}

criterion_group!(benches, bench_m3u_parser);
criterion_main!(benches);

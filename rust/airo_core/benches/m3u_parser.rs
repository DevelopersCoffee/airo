use std::{fs, path::PathBuf};

use airo_core::api::m3u::{
    parse_m3u_channels_with_stats, parse_m3u_entries, parse_m3u_file_channels_with_stats,
    parse_m3u_file_with_stats,
};
use criterion::{black_box, criterion_group, criterion_main, BenchmarkId, Criterion, Throughput};

fn iptv_org_fixture_path() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../iptv-data/fixtures/iptv-org/index.m3u")
}

fn bench_m3u_parser(c: &mut Criterion) {
    let fixture_path = iptv_org_fixture_path();
    let fixture = fs::read_to_string(&fixture_path).unwrap_or_else(|error| {
        panic!(
            "failed to read iptv-org fixture at {}: {error}",
            fixture_path.display()
        )
    });
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
        BenchmarkId::new("iptv_org_index_file", channel_count),
        &fixture_path,
        |b, path| {
            b.iter(|| {
                let result =
                    parse_m3u_file_with_stats(black_box(path.to_string_lossy().to_string()))
                        .expect("valid M3U fixture");
                black_box(result.playlist.entries.len())
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
    group.bench_with_input(
        BenchmarkId::new("iptv_org_index_file_channels", channel_count),
        &fixture_path,
        |b, path| {
            b.iter(|| {
                let result = parse_m3u_file_channels_with_stats(black_box(
                    path.to_string_lossy().to_string(),
                ))
                .expect("valid M3U fixture");
                black_box(result.channels.len())
            });
        },
    );
    group.finish();
}

criterion_group!(benches, bench_m3u_parser);
criterion_main!(benches);

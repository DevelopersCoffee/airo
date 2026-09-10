use criterion::{black_box, criterion_group, criterion_main, Criterion};
use m3u_parser::api::m3u::parse_m3u_playlist;

fn bench_parse(c: &mut Criterion) {
    let m3u = black_box(
        r#"#EXTM3U
#EXTINF:-1 tvg-id="news.one" tvg-name="News One" tvg-logo="https://example.com/news.png" group-title="News",News One
https://example.com/news.m3u8
"#
        .to_string(),
    );
    c.bench_function("parse_m3u_playlist", |b| {
        b.iter(|| parse_m3u_playlist(m3u.clone()))
    });
}

criterion_group!(benches, bench_parse);
criterion_main!(benches);

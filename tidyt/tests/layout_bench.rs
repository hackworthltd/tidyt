mod aesthetic_rules;
mod gen;

use std::time::Instant;

use criterion::{black_box, criterion_group, criterion_main, Criterion};
use rand::{prelude::StdRng, SeedableRng};
use tidyt::{BasicLayout, Layout, TidyLayout};

fn bench_tidy_layout_chart(_bench: &mut Criterion) {
    let mut layout = TidyLayout::new(10., 10.);

    let mut rng = StdRng::seed_from_u64(1001);
    let mut out = vec![];
    let (mut root, mut nodes) = gen::prepare_tree(&mut rng);
    for num in (1000..500_000).step_by(1000) {
        gen::insert_new_to_tree(&mut rng, 1000, &mut nodes);
        let start = Instant::now();
        layout.layout(&mut root);
        let time = Instant::now().duration_since(start);
        out.push((num, time.as_micros()));

        if num % 100_000 == 0 {
            println!("{}", num);
            assert!(root.x == 0.);
        }
    }

    for (num, time) in out {
        println!("{} {}", num, time);
    }
}

fn bench_naive_layout_chart(_bench: &mut Criterion) {
    let mut layout = BasicLayout {
        parent_child_margin: 10.,
        peer_margin: 10.,
    };

    let mut rng = StdRng::seed_from_u64(1001);
    let mut out = vec![];
    let (mut root, mut nodes) = gen::prepare_tree(&mut rng);
    for num in (1000..500_000).step_by(1000) {
        gen::insert_new_to_tree(&mut rng, 1000, &mut nodes);
        let start = Instant::now();
        layout.layout(&mut root);
        let time = Instant::now().duration_since(start);
        out.push((num, time.as_micros()));

        if num % 100_000 == 0 {
            println!("{}", num);
            assert!(root.x == 0.);
        }
    }

    for (num, time) in out {
        println!("{} {}", num, time);
    }
}

fn bench_tidy_layout(bench: &mut Criterion) {
    let mut rng = StdRng::seed_from_u64(1001);
    let mut tree = gen::gen_tree(&mut rng, 100_000);
    let mut layout = TidyLayout::new(10., 10.);

    bench.bench_function("tidy layout", |b| {
        b.iter(black_box(|| {
            layout.layout(&mut tree);
        }))
    });
}

fn bench_tidy_layout_large(bench: &mut Criterion) {
    let mut rng = StdRng::seed_from_u64(1001);
    let mut tree = gen::gen_tree(&mut rng, 1_000_000);
    let mut layout = TidyLayout::new(10., 10.);
    bench.bench_function("tidy layout large", |b| {
        b.iter(black_box(|| {
            layout.layout(&mut tree);
        }))
    });
}

fn bench_naive_layout(bench: &mut Criterion) {
    let mut rng = StdRng::seed_from_u64(1001);
    let mut tree = gen::gen_tree(&mut rng, 100_000);
    let mut layout = BasicLayout {
        parent_child_margin: 10.,
        peer_margin: 10.,
    };

    bench.bench_function("naive layout", |b| {
        b.iter(black_box(|| {
            layout.layout(&mut tree);
        }))
    });
}

criterion_group!(
    benches,
    bench_tidy_layout_chart,
    bench_naive_layout_chart,
    bench_tidy_layout,
    bench_tidy_layout_large,
    bench_naive_layout
);
criterion_main!(benches);

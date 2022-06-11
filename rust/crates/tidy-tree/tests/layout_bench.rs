#![feature(test)]

mod aesthetic_rules;
mod gen;
use rand::{prelude::StdRng, SeedableRng};
use tidy_tree::{BasicLayout, Layout, TidyLayout};
extern crate test;
use test::Bencher;

#[bench]
fn bench_tidy_layout(bench: &mut Bencher) {
    let mut rng = StdRng::seed_from_u64(1001);
    let mut tree = gen::gen_tree(&mut rng, 100_000);
    let layout = TidyLayout {
        parent_child_margin: 10.,
        peer_margin: 10.,
    };

    bench.iter(|| {
        layout.layout(&mut tree);
    });
}

#[bench]
fn bench_naive_layout(bench: &mut Bencher) {
    let mut rng = StdRng::seed_from_u64(1001);
    let mut tree = gen::gen_tree(&mut rng, 100_000);
    let layout = BasicLayout {
        parent_child_margin: 10.,
        peer_margin: 10.,
    };

    bench.iter(|| {
        layout.layout(&mut tree);
    });
}

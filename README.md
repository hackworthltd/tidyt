# `tidyt`

`tidyt` provides support for so-called "tidy tree" layouts. The layout algorithm implemented in `tidyt` is based on the paper [*Drawing Non-layered Tidy Trees in Linear Time*](https://core.ac.uk/download/pdf/301654972.pdf) by A.J. van der Ploeg.

`tidyt` is a hard fork of https://github.com/zxch3n/tidy (forked from [this commit](https://github.com/zxch3n/tidy/commit/54382fae3a9e85ac8329fa89d5a83632f20c2cde)). All credit goes to the original author, [Zixuan Chen](https://github.com/zxch3n), and we are grateful to him for his work! This fork exists primarily to provide robust packaging and CI, and especially focuses on reproducible builds via Nix. However, its functionality may diverge from upstream over time. (Note that `tidyt` drops everything from the upstream project except for its Rust packages.)

## License

`tidyt` is released under the same license as the original upstream project, namely the [MIT license](https://opensource.org/license/mit).

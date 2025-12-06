# DASL Testing

Test suite for [DASL](https://dasl.ing/).

Test results are available on the [website](https://hyphacoop.github.io/dasl-testing/).

Run the test suite locally by running `./run.sh` after installing all the dependencies.

## Dependencies
- Go
- Node and npm
- [uv](https://docs.astral.sh/uv/) for Python
- Rust (and `cargo`)
- Java 21 (LTS) and Maven
- [Swift](https://www.swift.org/install/) >= 6.0

Make sure to run `./update_libs.sh` before starting.

## Contributing

Look at the existing harnesses for reference. After creating your own, update `super_harness.sh`
and `update_libs.sh` to handle your new harness as well. Running `./run.sh` should now show
your harness in the report.

## License

This code is made available under the MIT license.

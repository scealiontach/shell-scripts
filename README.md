# Shell Scripts

This is a useful collection of shell scripts and libraries I've created
and assembled of the past couple of years.  In particular note the
library files `*.sh` which should be used wherever possible.

## Use

Typically you just need to add the relevant script directory to your
path.  If you need to copy them, be aware that the library scripts
sometimes refer to each other, and the command scripts typically
expect the `includer.sh` to live in the same directory as the command.

## Project structure

The `bash/` directory follows a deliberate two-way split that the
pre-commit hooks `script-must-have-extension` and
`script-must-not-have-extension` enforce:

* **Library files** (`bash/*.sh`) — sourced, never executed directly.
  Every function uses namespace qualification (`package::function`,
  e.g. `git::cmd`, `log::error`).
* **Command scripts** (`bash/*` with no extension) — executable; source
  `includer.sh`, pull in libraries with `@include`, and parse args with
  `options.sh`.

## Annotations

Libraries use a small set of inline annotations that `bash/bashadoc`
parses to render markdown documentation. They are defined in `doc.sh`
as no-op functions so they can appear directly in source:

```bash
@package mypkg                # at top of library, after @include lines

function mypkg::do_thing() {
  @doc One-line description of what this does
  @arg _1_ first positional arg
  @arg -o "<arg>" the -o flag
  ...
}
```

`bash/mddoc <file>` extracts literate-markdown blocks from a script —
any line beginning `## @md` becomes a markdown line in the output.
This is useful for keeping prose alongside the script that explains it.

## Building

The Makefile packages three tarballs into `dist/`:

* `doc-*.tar.gz` — markdown rendered by `bashadoc` for every `bash/*.sh`.
* `bin-*.tar.gz` — self-contained command scripts produced by
  `bash/pack-script`, which inlines all `@include` dependencies into
  one standalone bash file.
* `lib-*.tar.gz` — raw library sources.

Common targets:

```bash
make                     # default: package
make package             # explicit
make clean               # remove dist/
make what_version        # print VERSION / LONG_VERSION / MAVEN_REVISION
```

## Standards

* All scripts in this repository should pass a shellcheck and shfmt check
  before being committed.
* Scripts should be organized in folders according to their variant, if
  they are not specific to a given shell variant, then put them in the
  `bash` folder
* All command scripts should use options.sh to parse arguments and document
  their usage.
* Prefer dashes to underscores in script names
* Functions in include files (`*.sh`) should have a namespace qualification
  such as `function foo::bar` rather than just `function bar`

## Contributing

* Branch names must match `^(fix|feature|refactor|sprint)/[a-zA-Z0-9\-]+$` — the
  `no-commit-to-branch` pre-commit hook rejects commits on any other name.
* Commit messages follow Conventional Commits (`feat:`, `fix:`, `docs:`,
  `ci:`, …). `commitizen` enforces this at the `commit-msg` stage.
* Run `pre-commit run --all-files` before opening a PR; CI runs the same
  hooks (excluding `no-commit-to-branch`).

## Shell aliases (`bash/aliases`)

`bash/aliases` is a sourceable file of interactive shell helpers — add it to
your `~/.bashrc` or `~/.zshrc`:

```bash
source /path/to/shell-scripts/bash/aliases
```

It is **not** a command script and should not be added to `$PATH` directly.

Function families:

* **`k*` kubectl aliases** — `k`, `ku`, `kc`, `kn`, `kd`, `kl`, `kg`, `ke`,
  `kls`, `klc`, `klu`, `kln`; plus `ks` / `kss` for interactive exec into
  pods using bash or sh.
* **`update_*` binary updaters** — `update_helm`, `update_eksctl`,
  `update_kubectl`, `update_pip3_packages`, `update_packages`,
  `update_vundle`.
* **`ua` aggregator** — runs all `update_*` functions in sequence.
* **`get_latest_btp_branch`** — checks out the latest `btp-releases` branch
  across subdirectories.

**Security note:** `update_eksctl` and `update_kubectl` verify SHA-256 checksums
before installing (SUR-1863). `update_helm` uses an isolated temp dir with
`trap RETURN` cleanup but does not currently verify its download checksum.

## Build infrastructure (`standard_defs.mk`)

`standard_defs.mk` is a GNU Make include that most build targets in this
repository delegate to. See `AGENTS.md` for the canonical list of common
commands.

Published targets:

| Target | Description |
|--------|-------------|
| `build` | Compile / assemble artefacts |
| `test` | Run bats library specs and sprint regression scripts |
| `package` | Build all three tarballs into `dist/` |
| `analyze` | Run FOSSA licence analysis (requires `FOSSA_API_KEY`) |
| `archive` | Upload artefacts to a release archive |
| `publish` | Tag-driven `gh release` upload (see `RELEASABLE` below) |
| `gh-create-draft-release` | Create a draft GitHub release |
| `what_version` | Print `VERSION`, `LONG_VERSION`, and `MAVEN_REVISION` |

`RELEASABLE` is set to `yes` only when the current commit is exactly on a git
tag (`LONG_VERSION != VERSION` because `git describe --long` always appends
the commit-count suffix) **and** the working tree is clean. `make publish`
gate-checks this flag before uploading.

The toolchain image is `blockchaintp/toolchain:latest`.

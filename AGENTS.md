# AGENTS.md — this repository

Shared cross-agent instructions for this repository. Claude-specific
additions live in CLAUDE.md, which includes this file.

## Repository purpose

Personal collection of bash scripts and shared libraries. The build packages
three tarballs from `bash/`: documentation (`doc-*.tar.gz`), executable
commands (`bin-*.tar.gz`), and source libraries (`lib-*.tar.gz`).

## Common commands

```bash
make                     # default: package (builds all three tarballs in dist/)
make clean               # remove dist/
make package             # explicit package target
make publish             # tag-driven gh release upload (only when RELEASABLE=yes)
make what_version        # print VERSION / LONG_VERSION / MAVEN_REVISION
make test                # run bats library specs + tests/sur-*.sh sprint tests
make test_bats           # only the bats specs
tests/bats/bin/bats tests/<name>.bats     # run a single bats spec

pre-commit run --all-files                # full lint suite
pre-commit run shellcheck --all-files     # only shellcheck
pre-commit run shfmt --all-files          # only shfmt

bash/bashadoc bash/<lib>.sh               # generate markdown docs for one library
bash/pack-script -f <command> -o <out>    # inline @include deps -> standalone
```

CI (`.github/workflows/pre-commit.yaml`) only runs pre-commit hooks; Jenkins runs
`make clean build`, `make package`, `make analyze`, `make test`, `make archive`,
and on `main` `make publish`.

## Testing

Two complementary test layers live under `tests/`:

- `tests/*.bats` — library-level [bats-core](https://github.com/bats-core/bats-core)
  specs covering `commands`, `dirs`, `options`, `log`, `git`, `includer`,
  `semver`, and `update-repo-tags`. The runner is vendored as a git
  submodule pinned at `tests/bats`, so a fresh checkout needs
  `git submodule update --init` once.
- `tests/sur-*.sh` — per-sprint regression scripts driven by `tests/run.sh`
  and the helpers under `tests/lib/`. Add a new file when a sprint ships a
  regression that bats coverage doesn't naturally express (e.g. end-to-end
  pack-script roundtrips).

`make test` runs both layers. `pre-commit run --all-files` also invokes the
bats suite via the `bats` local hook.

To add a new bats spec:

- Create `tests/<thing>.bats` starting with `#!/usr/bin/env bats` and
  `setup() { load 'helpers.bash'; helpers::isolate_home; }`.
- Use `helpers::source_lib <name>` if you need to source a library
  directly, or shell out via
  `bash -c "source bash/includer.sh; @include <lib>; …"` for isolation.
- Run it locally with `tests/bats/bin/bats tests/<thing>.bats` before
  committing.

## Architecture

The code in `bash/` follows a deliberate split that is critical to understand:

- **Library files** end in `.sh` (e.g. `options.sh`, `git.sh`, `log.sh`). They
  are sourced, never executed directly. Every function in a library MUST use
  namespace qualification: `package::function` (e.g. `git::cmd`, `log::error`).
- **Command scripts** have no extension (e.g. `pack-script`, `changelog`,
  `clean-branches`). They are executable, source `includer.sh`, pull in
  libraries with `@include`, and use `options.sh` to parse args.
- **Naming**: script names use dashes, never underscores (convention only,
  not enforced by a hook). The pre-commit hooks `script-must-have-extension`
  and `script-must-not-have-extension` enforce the `.sh` ↔ no-extension split
  between libraries and command scripts.

### The `@include` mechanism

`includer.sh` defines `@include <name>` which sources `bash/<name>.sh` exactly
once per process. Deduplication uses a `cksum`-derived guard variable, so the
same include from multiple call sites is safe and cheap. Every library starts
with `source "$(dirname "${BASH_SOURCE[0]}")/includer.sh"` followed by its
`@include` declarations.

### Documentation annotations

`doc.sh` defines `@doc`, `@arg`, `@package` as no-op functions purely so they
can appear in source as inline annotations. `bash/bashadoc` parses these via
`declare -f` to produce markdown. Apply them as:

```bash
@package mypkg                # at top of library, after @include lines

function mypkg::do_thing() {
  @doc One-line description of what this does
  @arg _1_ first positional arg
  @arg -o "<arg>" the -o flag
  ...
}
```

The Makefile's `dist/doc-*.tar.gz` target runs `bashadoc` over every `bash/*.sh`.

### Building self-contained command scripts

`bash/pack-script` is the bin-tarball packer. It walks `@include` directives
transitively and produces a single bash file with `doc.sh` + `annotations.sh`
prepended, all `@include` lines stripped, and shebang/`includer.sh` references
removed. The Makefile's `dist/bin-*.tar.gz` target identifies command scripts
by `grep -q "includer"` AND no `.sh` extension — packing depends on those
two markers. Adding a new command without sourcing `includer` will silently
exclude it from the bin tarball.

### Options parsing

Commands declare options imperatively before parsing:

```bash
options::standard                                          # adds -v verbose
options::add -o f -d "input file" -a -m -e InputFile  # mandatory -> $InputFile
options::add -o x -d "dry run" -x DryRun                   # flag, sets DryRun=true
options::parse "$@"
shift "$((OPTIND - 1))"
```

`-e VAR` exports the value into a global; `-x VAR` marks a flag; `-f fn` calls
`fn` with the optarg. `-h` is added automatically. `options::parse` exits with
help if no args are provided unless `NO_SYNTAX_EXIT` is set.

Two additional public entry points exist for less common cases:

- `options::clear` resets the OPTIONS state (and re-adds `-h`). Useful when a
  script re-uses the framework across multiple option sets, or in tests that
  need a clean slate per case.
- `options::parse_available` is the body of `options::parse` without the
  no-args syntax-exit guard. Use it directly when the script accepts only
  positional arguments after the flags and you want to drop the implicit
  "exit on bare invocation" behaviour without setting `NO_SYNTAX_EXIT`.

## Conventions

- **Branch names**: pre-commit's `no-commit-to-branch` hook rejects *commits*
  on any branch not matching `^(fix|feature|refactor|sprint)/[a-zA-Z0-9\-]+$`.
  The hook runs only at commit time (the `pre-commit` stage) and is skipped in
  CI via `SKIP: no-commit-to-branch`. The regex restricts the suffix to
  `[a-zA-Z0-9-]` — underscores, dots, and nested slashes after the prefix
  slash are rejected. The check can be bypassed with `git commit --no-verify`
  (or `SKIP=no-commit-to-branch git commit`); for a hard guarantee, complement
  it with a server-side branch-protection rule. Use `feature/...`, `fix/...`,
  `refactor/...`, or `sprint/...`.
- **Commit messages**: commitizen runs at `commit-msg` stage, so conventional
  commits (`feat:`, `fix:`, `docs:`, `ci:`, etc.) are enforced.
- **Formatting**: shfmt with `-i 2 -ci` (2-space indent, indent switch cases).
  shellcheck runs with `-x -P SCRIPTDIR` so cross-file `source` directives
  resolve. Tabs are forbidden everywhere except `Makefile`, `*.mk`, and `*.go`.
- **Function namespacing**: anything in a `*.sh` library must be
  `package::name`. Bare `function bar()` is reserved for command scripts and
  for backward-compat shims that delegate via `deprecated newfunc::name "$@"`
  (see `annotations::deprecated`).
- **`commands::use <bin>`** caches a `command -v` lookup in `$_<bin>` and
  errors out if missing. Prefer `$(commands::use awk)` over bare `awk` in
  libraries that should fail loudly when a tool is absent.

Linear Project: shell-scripts

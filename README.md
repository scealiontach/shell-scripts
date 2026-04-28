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

* Branch names must match `^(fix|feature|refactor)/[a-zA-Z0-9\-]+$` — the
  `no-commit-to-branch` pre-commit hook rejects commits on any other name.
* Commit messages follow Conventional Commits (`feat:`, `fix:`, `docs:`,
  `ci:`, …). `commitizen` enforces this at the `commit-msg` stage.
* Run `pre-commit run --all-files` before opening a PR; CI runs the same
  hooks (excluding `no-commit-to-branch`).

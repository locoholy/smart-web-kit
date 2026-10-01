# Changelog

## 1.7.1

Install and verification changes; the read ladder is unchanged.

- **Standalone binary.** `./install.sh` now compiles `swr` and the skill text
  into one executable in `~/.local/bin` (`tools/build.sh`, needs `bun` at build
  time only). The installed command no longer depends on the checkout staying
  on disk. `./install.sh --link` keeps the old symlink for development.
- **`init` no longer depends on where it runs from.** The skill text is
  resolved beside the script, then `SWR_SKILL_SRC`, then the text embedded in a
  compiled binary, then the copy in `~/.agents/skills`. The embedded text comes
  before the installed copy so a binary never compares a deployment against
  itself.
- **Version stamp.** `init` writes `version: <package.json version>+swr` into
  the frontmatter of every copy it deploys, and `doctor --skills` reports
  `STALE` (older release), `MODIFIED` (edited by hand), `UNSTAMPED` (predates
  stamping) or `MISSING` per root, instead of only "differs".
- `doctor --skills` no longer lets a clean install read as a hand edit: the
  stamp line is removed with its newline before the text comparison.
- Tests: 58 cases, covering the stamp, the four `doctor --skills` verdicts, and
  a run against an installed binary (`SWR=... ./tests/run.sh`).

# gh-issues-map

A tiny shell script that renders a dependency map of the GitHub Issues in the
current repo: which issue blocks which, what's done, and what is **workable
right now** (the "frontier").

Originally written to make sense of issue-driven projects that use GitHub's
"blocked by" relationships to encode a dependency graph between issues.

## What it prints

For every issue in the repo, one row:

```
#  | state | blocked by        | status            | title
```

- **blocked by** — the issues that block this one. A `✓` next to a number means
  that blocker is closed and no longer gates the work.
- **status** —
  - `◀ FRONTIER` — open with no open blockers → you can start this now.
  - `waiting (#N, …)` — open, but blocked by the listed open issues.
  - `done ✓` — closed.

After the table it prints a `Workable now:` list of all frontier issues. If
none exist, it says the frontier is empty.

## Requirements

- [`gh`](https://cli.github.com/) (GitHub CLI), authenticated
- `jq` and `column` (present on most Linux/macOS systems)

The repo you run it in must use GitHub's issue dependency feature
(Issue → "Blocks / Blocked by"). Without dependencies set, every open issue
just shows as frontier.

## Usage

From anywhere inside the repo:

```sh
./gh-issues-map
```

Switch repos the usual `gh` way — `cd` into another repo, or set
`GH_REPO`/`--repo`. The script relies on `gh`'s own repo resolution, so anything
`gh repo view` understands will work.

## Notes

- Pulls up to 200 issues (open + closed). Bump `--limit` in the script for larger
  repos.
- Calls the `repos/:owner/:repo/issues/:n/dependencies/blocked_by` API once per
  issue, so big repos will be rate-limited eventually. Run it, grab the output,
  move on.
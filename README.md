# gh-issues-map

A tiny shell script that renders a dependency map of the GitHub Issues in the
current repo: which issue blocks which, what's done, and what is **workable
right now** (the "frontier").

Originally written to make sense of issue-driven projects that use GitHub's
"blocked by" relationships to encode a dependency graph between issues.

## What it prints

By default it groups issues by **PRD** — an issue that has sub-issues, carries
the `spec` label, or whose title starts with `PRD:`. Each PRD is rendered in
ascending number order, with its child issues in ascending order beneath a
header showing progress:

```
PRD: Thread profile - shared recommendation graphs   (#18)   2/15 done
  #   state   blocked by   status        title
  19  CLOSED  —            done ✓        Thread Workspace bootstrap in OpenTUI
  21  OPEN    —            ◀ FRONTIER    Safe offline and divergent Git sync
  ...
```

- A fully closed PRD is still rendered in full, but with a muted "finished"
  palette so it recedes next to active work.
- A `PRD:` title with no linked sub-issues prints `⚠ no linked children`, so a
  missing link is visible rather than silently dropped.
- Parentless non-PRD issues appear under **Unassigned**.

Each row has the columns:

```
#  | state | blocked by        | status            | title
```

- **blocked by** — the issues that block this one. A `✓` next to a number means
  that blocker is closed and no longer gates the work.
- **status** —
  - `◀ FRONTIER` — open with no open blockers → you can start this now.
  - `waiting (#N, …)` — open, but blocked by the listed open issues.
  - `done ✓` — closed.

After the table it prints a `Workable now:` list of all frontier issues, grouped
by PRD the same way. If none exist, it says the frontier is empty.

Pass `--flat` for the original single table sorted by issue number (no PRD
grouping), followed by a flat `Workable now:` list.

## Requirements

- [`gh`](https://cli.github.com/) 2.95.0 or later, authenticated
- `jq` and `column` (present on most Linux/macOS systems)

Color is shown when writing to a terminal. Set `NO_COLOR=1` to disable it.

The repo you run it in must use GitHub's issue dependency feature
(Issue → "Blocks / Blocked by"). Without dependencies set, every open issue
just shows as frontier.

PRD grouping relies on GitHub's **real** sub-issue relationships
(Issue → "Parent issue"), not on a `Parent: #N` line in the body — a text
mention is not a sub-issue and will not group. A spec that has no tickets yet
is still grouped if it carries the `spec` label. To link an issue as a child:

```sh
gh api --method POST repos/<owner>/<repo>/issues/<parent>/sub_issues \
  -F sub_issue_id="$(gh api repos/<owner>/<repo>/issues/<child> --jq .id)"
```


## Registering with `gh`

The script follows the `gh` extension naming rule — the repo, the extension
name, and the executable all match exactly (`gh-issues-map`), with no `.sh`
suffix. That lets `gh` discover and install it as a first-class subcommand
(`gh issues-map`).

### Install from GitHub (canonical)

If you just want to use it, install from the published repo:

```sh
gh extension install rigofekete/gh-issues-map
```

`gh` fetches the `gh-issues-map` executable at the repo root and exposes it as
`gh issues-map`. Verify with:

```sh
gh extension list
gh issues-map
```

Upgrades: `gh extension upgrade issues-map`. Removal:
`gh extension remove issues-map`.

### Local dev (this clone)

If you cloned this repo to hack on the script, point `gh` at your working
copy instead of the published one. Symlink it into `gh`'s extensions
directory (`~/.local/share/gh/extensions/` on Linux; the equivalent under
`%LOCALAPPDATA%\gh\extensions` on Windows) and make sure it's executable:

```sh
mkdir -p ~/.local/share/gh/extensions/gh-issues-map
ln -sf "$(pwd)/gh-issues-map" ~/.local/share/gh/extensions/gh-issues-map/gh-issues-map
chmod +x ./gh-issues-map
```

The symlink is named `gh-issues-map` and lives inside a `gh-*` subdir, so `gh`
dispatches `gh issues-map` to it. Confirm with `gh extension list`. Edit the
script in place — the symlink picks up changes immediately.

## Usage

From anywhere inside the repo:

```sh
./gh-issues-map
```

…or, once registered as above:

```sh
gh issues-map
gh issues-map --flat    # original single sorted table
gh issues-map --help
```

Switch repos the usual `gh` way — `cd` into another repo, or set
`GH_REPO`/`--repo`. The script relies on `gh`'s own repo resolution, so anything
`gh repo view` understands will work.

## Notes

- Pulls up to 500 issues (open + closed). Bump `--limit` in the script for larger
  repos.
- Fetches issues and their blockers together, rather than requesting blockers
  separately for every issue.

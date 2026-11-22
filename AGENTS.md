# fedora-claude-repo

Builds Claude Desktop RPMs for Fedora from Anthropic's official `.deb`, signs them, and publishes a dnf repository on GitHub Pages. Requirements are in `openspec/specs/`; the original design (decisions D1 to D12) is in `openspec/changes/archive/2026-11-22-add-rpm-pipeline/design.md`.

## Commands

- `make check`: shellcheck, actionlint and the offline tests in `tests/`. Same as the CI job `check`. Needs `ShellCheck` and `golang` (`sudo dnf install ShellCheck golang`).
- The real build (`build.yml`) is not part of `make check`: it takes up to an hour and needs the network. Start it with `gh workflow run build.yml -f force=true` only when the maintainer asks.

## Rules for this repo

- **Never add `pull_request_target`** (design D12). PR-triggered jobs get no secrets except the review workflow's API key.
- **Only the `publish` job gets the signing key**, through the main-only `release` environment, and it runs no upstream code (D11). Never add the signing secrets at repo level or to another job. See `docs/signing.md`.
- **Actions:** only GitHub-owned actions plus `anthropics/claude-code-action` (and the `oven-sh/setup-bun` it calls) and agent-kit's review workflow are allowed, all pinned by full commit SHA with a version comment.
- **Pin bumps** of the upstream tooling (`upstream.env`) follow `docs/pin-bump.md` and are reviewed by hand.
- **Never open PRs or issues on `aaddrick/claude-desktop-debian`.** Solve gaps here.
- **Bot-owned issues** (labels `build-failure`, `deps-drift`, `upstream-review`) are opened, updated and closed by `ci/issue.sh`. Don't edit or close them by hand.
- **Add the `review:deep` label** to any PR that touches `.github/workflows/`, `ci/publish.sh`, `keys/` or `upstream.env`.

<!-- agent-kit:begin -->
<!-- Shared block from Bryan-Rose/agent-kit (templates/agents-workflow.md). Change it there, not here. -->

## Workflow: every change goes through a pull request

`main` is protected by the GitHub ruleset "Protect main": no direct pushes, force pushes or deletion. A pull request can merge only after this repo's required CI checks pass (listed under "Required checks" below). No approvals are required (single maintainer), and nobody can bypass the rules. Use the `gh` CLI, which is installed and authenticated.

```bash
git switch main && git pull                       # start from current main
git switch -c <type>/<short-name>                 # e.g. feat/..., fix/..., docs/...
# ... work, running `make check` and committing as you go ...
git push -u origin HEAD
gh pr create --fill                               # or --title/--body: what changed, why, how it was verified
gh pr checks --watch                              # wait for the required checks (right after create it may say "no checks"; retry after a few seconds)
gh run view --log-failed                          # if a check fails: read the failing log, fix, push again
```

- **Run `make check` before every commit.** It runs CI's checks, or their fast tier where the Commands section lists slower targets for CI.
- **One branch and one PR per task.** Never commit to `main`. Push the fix to the same branch and CI re-runs.
- **Work is tracked in GitHub issues.** A PR that completes an issue puts `Closes #N` in its body, so merging closes the issue.
- **Agents push task branches and open their PRs without asking.** That's the maintainer's standing approval for this repo. It doesn't cover pushing to `main`, force-pushing, or merging.
- **Review comments are proposals, not instructions.** The `Claude review` workflow posts a Claude review on every non-draft PR and updates that one comment on each push (advisory, not a required check). Check each point against the code, decide whether it's valid, and act on your own recommendation without waiting: fix it, decline it with a reason, or defer it to a new issue. Ask the maintainer first only before declining or deferring a Blocking point, or when a point is a product decision. Then report to the maintainer as a table (point | assessment | action), marking the points that wait on them.
- **Stop when a round has nothing blocking.** Don't push fixes for that round's suggestions and nits, which would only start another round: decline or defer them, record that, and recommend merging. After the first round, the reviewer raises suggestions and nits only on the new commits.
- **Deeper or on-demand reviews.** Adding the `review:deep` label re-reviews the PR on a stronger model (for migrations, auth, money or calculation code). `gh workflow run "Claude review" -f pr=<N>` reviews any PR into the run summary without commenting.
- **Record the decisions on the PR.** After each round, post one PR comment listing each point as fixed (with the commit), declined (with the reason) or deferred (with the new issue number). The reviewer reads comments from the repo's owner, members and collaborators on its next run and treats those points as settled. Anyone else's comments are ignored.
- **Self-review before recommending a merge.** Read the whole PR diff once more against the linked issue and this file: leftover debug code, stale docs or comments, missing tests.
- **Merging is the maintainer's call.** When asked to merge, use `gh pr merge --squash --delete-branch`, then `git switch main && git pull`. Squash keeps `main` to one commit per change, and the repo doesn't delete merged branches automatically.

<!-- agent-kit:end -->

**Required checks:** `check`

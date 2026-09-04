English | [简体中文](CONTRIBUTING.zh-CN.md)

# Contribution and branch workflow

Use `feat/* -> dev -> main`. `main` is the release baseline; `dev` is the integration branch. Both require pull requests, successful checks, and resolved conversations. Direct pushes, force pushes, and deletion are blocked, with no bypass actors. Human approvals are not required for this single-maintainer repository.

## Develop and integrate

```sh
git fetch origin
git switch -c feat/your-change origin/dev
# Make and test a focused change, then commit it.
git push -u origin feat/your-change
```

Open a PR into `dev`. After all required checks pass, merge it using **Create a merge commit**. To release the integrated changes, open a separate PR from this repository's `dev` into `main`; checks run again. Feature branches cannot merge directly into `main`. The trusted base-branch `Branch flow` workflow validates PR metadata without checking out or executing PR code.

The required checks are **Branch flow**, **Build and test**, **Dependency review**, **CodeQL (Swift)**, and **CodeQL (Actions)**. Checks must pass against an up-to-date target branch. CodeQL scans the application and tools plus workflow definitions; its job fails on reported findings, not merely on scan/upload failure. Dependency review blocks newly introduced known vulnerabilities of low severity or above, including development dependencies. Its coverage is limited to dependencies GitHub can detect; new Swift dependencies must have a committed `Package.resolved` lockfile. Automated scanning is not a guarantee that code is vulnerability-free.

Code scanning results are additionally enforced through the GitHub ruleset. Never remove a failing check, change its name, or weaken the policy just to merge. Changes to `.github/workflows/` should be reviewed carefully even though a second human approval is not mandatory. GitHub administrators can still edit repository rules; this is not an immutable organizational policy.

After `dev -> main` merges, CI packages and publishes a commit-specific GitHub Release automatically. The existing **Build and test** check also validates Universal packaging before merging. See [Automatic GitHub Releases](README.md#automatic-github-releases) for artifacts, tags, signing limits, and retries.

## Synchronize after a release

Keep merge commits so ancestry is preserved. A release PR creates a merge commit on `main`; bring it back through a feature PR instead of pushing to `dev`:

```sh
git fetch origin
git switch -c feat/sync-main origin/dev
git merge origin/main
git push -u origin feat/sync-main
# Open feat/sync-main -> dev and wait for all checks.
```

Then create new feature branches from the updated `origin/dev`. Do not delete the long-lived `dev` branch after a release.

## Local validation

Run `swift test` and the macOS Debug build described in the README. GitHub CI uses hosted macOS runners and does not substitute for real-device UI/performance acceptance or Apple distribution signing.

Git commit identity is separate from push authentication. Use the intended public author identity for commits; never commit private keys or personal IDE state.

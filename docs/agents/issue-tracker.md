# Issue tracker

Issues for this repo are tracked in **GitHub Issues**, accessed through the [`gh`](https://cli.github.com/) CLI.

Skills that read from or write to the issue tracker (`to-issues`, `triage`, `to-prd`, `qa`, and similar) should use `gh` to create, read, label, and comment on issues.

## Common commands

- Create an issue: `gh issue create --title "..." --body "..."`
- List open issues: `gh issue list`
- View an issue: `gh issue view <number>`
- Add labels: `gh issue edit <number> --add-label "<label>"`
- Comment: `gh issue comment <number> --body "..."`

## Pull requests as a request surface

**External PRs are part of the triage queue.** A PR is treated as an issue with attached code. When `/triage` runs, it pulls in *external* pull requests and runs them through the same labels and states as issues.

- Collaborators' in-flight PRs are left alone — they are not external requests.
- List PRs: `gh pr list`
- View a PR: `gh pr view <number>`
- Label/comment on a PR uses the same `gh pr edit` / `gh pr comment` commands.

## Setup status

Remote is configured and pushed to GitHub; the `gh` CLI is installed and authenticated. The `gh`-based workflow is live. Remaining one-time step: create the five triage labels (see `triage-labels.md`).

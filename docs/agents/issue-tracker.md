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

> **Not yet wired up.** As of setup, this repo has **no git remote configured** and is not yet pushed to GitHub. Before the `gh`-based workflow will work you need to:
>
> 1. Initialise git if needed: `git init`
> 2. Create the GitHub repo and remote, e.g. `gh repo create` (requires `gh auth login` first).
> 3. Push: `git push -u origin main`
>
> Until then, skills that call `gh` against this repo will fail. Update or delete this note once the remote exists.

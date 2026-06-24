# Triage labels

When the `triage` skill processes an incoming issue (or external PR), it moves it through a state machine and applies the matching label. The five canonical roles below use their **default** label strings — change the right-hand column if you rename or remap any label in GitHub, so the skill applies your existing labels instead of creating duplicates.

| Role | What it means | Label string |
| --- | --- | --- |
| `needs-triage` | Maintainer needs to evaluate | `needs-triage` |
| `needs-info` | Waiting on the reporter | `needs-info` |
| `ready-for-agent` | Fully specified, AFK-ready — an agent can pick it up with no human context | `ready-for-agent` |
| `ready-for-human` | Needs human implementation | `ready-for-human` |
| `wontfix` | Will not be actioned | `wontfix` |

## Creating the labels

Most of these don't exist in a fresh GitHub repo — but `wontfix` **is** a GitHub default
label, so a plain `gh label create wontfix` will fail with "already exists". Use `--force`
(create-or-update) so the whole block is idempotent and safe to re-run. Once the remote is set
up (see `issue-tracker.md`), create them with:

```bash
gh label create needs-triage    --description "Maintainer needs to evaluate"      --color FBCA04 --force
gh label create needs-info       --description "Waiting on the reporter"            --color D876E3 --force
gh label create ready-for-agent  --description "Fully specified, AFK-ready"         --color 0E8A16 --force
gh label create ready-for-human  --description "Needs human implementation"         --color 1D76DB --force
gh label create wontfix          --description "Will not be actioned"               --color CCCCCC --force
```

Add `--repo etterognuller/Kiosk` to each command if you're running from outside the repo
folder. GitHub's other default labels (`bug`, `enhancement`, `duplicate`, `good first issue`,
`help wanted`, `invalid`, `question`) are left in place unless you choose to delete them with
`gh label delete <name>`.

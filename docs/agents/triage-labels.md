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

These labels don't exist in a fresh GitHub repo. Once the remote is set up (see `issue-tracker.md`), create them with:

```bash
gh label create needs-triage    --description "Maintainer needs to evaluate"      --color FBCA04
gh label create needs-info       --description "Waiting on the reporter"            --color D876E3
gh label create ready-for-agent  --description "Fully specified, AFK-ready"         --color 0E8A16
gh label create ready-for-human  --description "Needs human implementation"         --color 1D76DB
gh label create wontfix          --description "Will not be actioned"               --color CCCCCC
```

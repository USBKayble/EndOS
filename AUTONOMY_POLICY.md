# AUTONOMY_POLICY

This repository uses automated workflows to assist maintainers. The policy below defines the allowed autonomous actions and safeguards.

Auto-merge policy
- PRs must not be merged unless all required checks are passing.
- At least one approving review from a human reviewer is required before auto-merge.
- Dependabot/automation PRs may be auto-merged if all checks pass and they only contain dependency metadata changes.

CI and triage
- When a CI workflow fails, an issue labeled `ci`, `failure`, and `needs-triage` will be created automatically.
- The automation will attempt basic diagnosis by linking logs and creating comments on associated PRs.

Human oversight
- Any changes to release files, version numbers, or publishing workflows must be approved by a designated maintainer.
- Destructive actions (deleting branches, force-push to protected branches) are forbidden for automated agents.

Secrets & tokens
- All tokens used by automation will be stored as GitHub Secrets. Do not paste tokens in chat.

Contact & notification
- Notifications for failures and merges will be sent to repo configured channels.
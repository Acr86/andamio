# Demo recording for the README, rendered with vhs (https://github.com/charmbracelet/vhs).
# Rendered in CI by .github/workflows/demo.yml (Linux: vhs needs ttyd), but the
# tape is portable — `vhs docs/demo/golden-path.tape` works on any machine with
# vhs + uv where the repo is a git checkout.
#
# It records the cluster-independent golden path: one command scaffolds a
# service (code + manifests + catalog entry), the catalog stays consistent,
# and the service is on the platform. The cluster side (GitOps deploy, preview
# environments) is proven by the e2e-bootstrap CI job — see docs/capabilities.md.
Output docs/demo/golden-path.gif

Require uv
Require git

Set Shell bash
Set FontSize 18
Set Width 1280
Set Height 720
Set Theme "Catppuccin Mocha"
Set TypingSpeed 35ms
Set Margin 16
Set MarginFill "#1e1e2e"
Set BorderRadius 10

# Enter the repo root (portable) and clear any prior demo artifacts, quietly.
Hide
Type "cd $(git rev-parse --show-toplevel)" Enter
Type "alias platform='uv run --project platform-cli platform'" Enter
Type "rm -rf services/payments-ledger deploy/kustomize/services/payments-ledger catalog/payments-ledger.yaml" Enter
Type "clear" Enter
Show

Sleep 800ms
Type "# One command scaffolds a service: code, deploy manifests and catalog entry." Enter
Sleep 500ms
Type "platform new service payments-ledger --owner team-treasury --tier t3 -d 'Posts ledger entries for settled payments.'" Enter
Sleep 3.5s

Type "# Three artifacts, one pass — no separate 'register the service' step:" Enter
Sleep 500ms
Type "git status --short services catalog deploy" Enter
Sleep 3s

Type "# The catalog can't drift from the repo. The same gate CI runs on every push:" Enter
Sleep 500ms
Type "platform validate" Enter
Sleep 2.5s

Type "# And the service is on the platform, ready for GitOps to deploy on merge:" Enter
Sleep 500ms
Type "platform list" Enter
Sleep 4s

Hide
Type "rm -rf services/payments-ledger deploy/kustomize/services/payments-ledger catalog/payments-ledger.yaml" Enter
Show

# Docker-only project runs — patch v1.3

Policy: every execution that touches project code — the headless agent AND all
checks/tests — runs inside the harness-runner container. Host scripts only orchestrate.

## Files → destinations
- docker/Dockerfile, docker/claude-run.sh, docker/exec.sh → repo docker/ (new)
- evals/run.sh → replace (docker-only + clone-instead-of-worktree + BSD grep fix + empty-run detector + EVAL_LIMIT + progress echo)
- ci/harness-evals.yml → replace (builds the image; parity local/CI; sample-on-PR via github.event_name, not branch name)
- tests/runner-smoke.sh → repo tests/ (new; the runner's own smoke test)

## Why clone instead of worktree
A worktree's .git is a file with an ABSOLUTE HOST path to the main repo —
mount only the worktree into a container and git breaks. A local `git clone`
is self-contained and equally fast (hardlinks).

## README additions
- Requirements: + Docker (mandatory for evals/headless runs)
- Security model: + layer 0 — "container boundary for all headless runs"
- Changelog v1.3

## Acceptance
1. docker build -t harness-runner:latest docker/
2. ./tests/runner-smoke.sh   → expect "Pass rate: 1/1" and a real diff in the fixture
3. In the target Go project: EVAL_LIMIT=1 ./evals/run.sh → PASS on trace 001

## Known boundary (document, don't hide)
Network egress from the container is NOT restricted (the agent needs
api.anthropic.com). For strict egress, add an allowlist firewall to the image —
see Anthropic's reference devcontainer for the pattern. Interactive sessions
remain on the host guarded by permissions+hooks; this policy covers headless
project runs. If you want interactive-in-docker too, that's a devcontainer
setup — a separate step.

## Before you open a PR (local checks)

Run the same gates CI will run:

    bash -n hooks/*.sh install.sh evals/run.sh   # syntax
    ./tests/hooks-test.sh                        # guard/scan regression cases
    docker build -t harness-runner:latest docker/
    ./tests/runner-smoke.sh                      # eval runner end-to-end

A PR opened without these passing locally will just fail the same checks in CI.

## Commit messages

Conventional commits, same as the kit's own /commit command enforces:
`type(scope): description` — feat / fix / docs / test / chore / refactor.
The kit should be developed the way it tells users to develop.

## AI-assisted contributions

Fine — this project exists because of agentic coding. Two conditions:
you must understand every line you submit well enough to defend it in review,
and agent-written security-relevant shell changes still require the human-added
regression test from "PR requirements". "Claude wrote it" is not a review answer.

## License of contributions

By submitting a PR you agree your contribution is licensed under this
repository's MIT license. No CLA, no paperwork.
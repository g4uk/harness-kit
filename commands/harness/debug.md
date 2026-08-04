---
description: Systematic debugging — reproduce, isolate, fix with evidence
---
Debug "$ARGUMENTS" (a symptom, a failing test, or a failing eval trace name).

1. REPRODUCE: get a failing command with observable output before proposing any fix.
   No reproduction yet = no diagnosis, only a guess.
   - Regular test/build failure → reproduce it directly.
   - Failing eval trace → `EVAL_TRACES="<name>" harness/evals/run.sh` to isolate just
     that trace instead of re-running the whole accumulated set. Check
     `harness/evals/results/*.md` first — the RAW OUTPUT / AGENT ERROR / FAIL block
     from the last run may already have the cause.
   - Need to poke inside the sandbox directly → `harness/docker/exec.sh <dir> "<cmd>"`
     (same container CI checks run in).
2. ISOLATE: bisect to the smallest reproduction — one input, one command, one file.
   Read the actual error, not a symptom one layer removed from it.
3. HYPOTHESIZE: state ONE hypothesis for the root cause before touching code. If you
   can't state it in a sentence, you don't understand it yet — keep isolating.
4. TEST THE HYPOTHESIS: smallest change or added diagnostic (log/assert) that would
   prove or disprove it. Confirm the cause before writing the real fix.
5. FIX: minimal change addressing the confirmed root cause, not the symptom.
6. VERIFY: rerun the reproduction from step 1 — green.

Show the confirmed root cause and the fix. Do not silently expand scope beyond it.
After merge: if this bug class is worth catching automatically next time, route it via
/harness:retro — a new `harness/evals/traces/NNN-*.md` check, or a CLAUDE.md/skill rule
— not just a one-off fix.

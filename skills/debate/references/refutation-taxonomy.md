# Refutation taxonomy — code and design

The checklist a challenger attacks with, and the list a judge scores against.
Adapted from the adversarial-verifier pattern, where the finding was: a solver
that verifies its own work reports ~86% success and a fresh adversarial grader
finds under 5%. The fix was never "review harder" — it was a *named taxonomy*
plus a verifier that never saw the author's reasoning.

Generic "look for problems" produces agreement. A taxonomy produces dissent.

## Part 1 — The twelve attacks

Each attack is a question with a code-shaped answer. If none of the twelve fires
after a genuine attempt on an axis, that axis closes clean — say so. Do not
manufacture a point to look useful.

### Approach level

1. **Solves the wrong problem.** The change satisfies the literal request and
   misses the actual need, or fixes a symptom whose cause is one layer down. Ask:
   what did the user/task actually want, and does this deliver it?
2. **A simpler design meets every stated requirement.** Name that design. If the
   simpler design fails a requirement, this attack does not fire — say which
   requirement kills it and move on.
3. **The abstraction has exactly one implementation** and no named second caller
   in sight. Or the inverse: a real seam was inlined and the next caller will
   have to fork it.

### Contract level

4. **The contract lies.** A type, DTO, or generated client says something the
   runtime does not honour — nullable that is never null, non-null that is,
   enum widened, a field that only exists on one path. Across repos/packages also:
   backend changed, generated client not regenerated.
5. **Unhandled state exists in the state space.** Enumerate the states the new
   code admits (loading × empty × error × partial × stale × concurrent) and name
   one the code cannot express or renders wrongly.
6. **No migration story.** Old rows, in-flight requests, cached payloads,
   already-deployed clients. "We'll figure it out" is a finding.

### Correctness level

7. **Fails on a concrete input.** Produce the input. Empty array, one element,
   duplicate ids, unicode, negative, zero, the 15th locale, timezone boundary,
   the retry. Trace it through and say what comes out.
8. **Concurrency or ordering breaks it.** Two requests, a re-render mid-fetch, a
   retried transaction body, a websocket arriving before the fetch resolves,
   read-then-write where an atomic op was needed.
9. **The error path is ceremonial.** The catch swallows, logs and continues into
   code that needed the value; a rejected promise leaves state half-written; a
   failure is reported as success to the user.

### Cost and operability level

10. **The cost is quadratic in something real.** N+1 query, a fetch per row, a
    re-render per keystroke over a list that grows, a full collection scan with
    no index, an unbounded payload. Say what N is in production, not in theory.
11. **Nothing is observable at 3am.** The failure this code will actually have
    produces no log, no metric, no distinguishable user-facing state. Name the
    incident and what the on-call engineer would be missing.
12. **It duplicates something that already exists** in this repo. Name the file.
    (Grep before claiming this — an unfound duplicate is not a duplicate, and
    this is the attack most often raised on a guess.)

## Part 2 — Admissibility

A point enters the debate only with all four of these. This is the valve that
separates a debate from two agents generating text at each other.

- **SCENARIO** — the concrete input, state, or path. Not "could be unsafe";
  rather "two clients POST the same id within the retry window, and then …".
- **EVIDENCE** — `file:line` you actually opened, and what it said. A point
  raised from the hunk alone, without the definition that decides it, is
  inadmissible. Open the provider, the schema, the guard, the sibling writer.
- **ALTERNATIVE** — the specific better thing. "Use a transaction" is not an
  alternative; "wrap the two writes in one DB transaction and move the event
  emit into an after-commit hook" is.
- **COST OF ALTERNATIVE** — what your alternative makes worse. Every real
  engineering choice trades something. An alternative presented as free is
  either trivial or not understood, and the judge treats a missing cost as the
  latter.

Inadmissible points are dropped before cross-examination. They are not
softened, not downgraded, not carried as "worth noting". Dropped.

## Part 3 — Out of scope for a debate

These are not debatable and raising them wastes a round:

- Formatting, naming preference, import order, comment style.
- Anything the repo's deterministic checkers (linters, type-checker, CI
  scripts) already own, or that the repo's review guidelines say not to report.
- Anything the repo explicitly allows (see `AGENTS.md` / `CLAUDE.md` and any review
  guidelines). Debating a deliberate, documented choice is noise, not courage.
- Pre-existing problems in untouched code. Note them once at the end as
  out-of-scope context, never as a debate point.
- Hypotheticals with no path from the current code ("if we later add
  multi-tenancy…"), unless the change itself forecloses that path — which is
  attack 3, and needs the same admissibility.

## Part 4 — Notes for the defender

Defending is not the same as disagreeing.

- The measure of a good defender is **conceding fast and precisely** on the
  points that are real, so the round's whole budget goes to the ones that are
  not. A defender who concedes nothing has not read the challenge.
- A concession is specific: what exactly is wrong, and what the fix is. "Fair
  point, I'll look at it" is not a concession.
- "That's how the existing code does it" is a fact, not an argument — unless
  consistency is the *reason*, in which case say why divergence costs more than
  the improvement.
- Refuting means new evidence the challenger did not have: the guard they
  missed, the caller that makes their scenario unreachable, the index that
  already exists. Restating your opening louder is not a refutation, and the
  judge scores it as a non-answer.

## Part 5 — Notes for the judge

- **You do not average.** Each contested point resolves to CHALLENGER,
  DEFENDER, or UNRESOLVED. Splitting the difference on a technical question
  produces advice nobody can act on.
- **Verify, do not referee.** You have the repo. On any point where one line of
  code settles it, open that line. The better-argued side is often the wrong
  one, and rhetoric is exactly what you are here to discount.
- **Asymmetric bar.** Upholding a challenge costs the author work, so a
  challenge wins only with a scenario you traced and believed. A defence wins by
  default when the challenge is speculative — but "the defender rebutted
  confidently" is not a defence.
- **UNRESOLVED is a real verdict, not a failure.** Use it when the point is a
  genuine tradeoff with no dominant side (both sides' costs are real and the
  choice depends on something only a human knows — roadmap, deadline, appetite
  for risk). State the tradeoff in one line each way and hand it to the user.
  Do not resolve it by picking the side that wrote more.

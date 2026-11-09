---
name: focused-course-labs
description: Restructure technical course material into short lessons and small, independent practical labs; align teaching with graded outcomes, fill coverage gaps, and automate lab verification. Use for course or lab authoring and curriculum reviews, not ordinary product documentation or exam-question generation alone.
---

# Focused Course Labs

Build a course in which a learner reads a skill, practices it, and proves the result before moving to a different outcome. Adapt the repository's existing course format and runtime instead of imposing a new platform.

## Establish scope and map coverage

Read the repository's authoring guidance, course outline, representative lessons, lab configurations, reference solutions, graders and CI workflow. Check the working tree before editing. Treat an approved pilot as evidence for the requested rollout; do not infer permission to restructure unrelated courses.

Map each assessable outcome to:

- the lesson that teaches it;
- the lab and its starting state;
- the learner's observable result;
- the grader that proves it;
- the automated test that exercises it.

Use this map to find gaps and misplaced labs. A concept mentioned in a reading is not necessarily practiced. Conversely, a grader must not demand an operation the material never teaches. Add a lab when it fills a meaningful practical gap; definitions and supporting concepts can prepare a later lab without needing separate exercises.

## Choose useful lab boundaries

Default to **3–5 concrete tasks and 10–15 minutes of learner work** per module lab when shortening a course. Follow a different explicit user target. State startup, rollout and telemetry delays separately from task time.

Group tasks around one outcome, such as restoring one scrape target or proving one recording rule. Split independent faults, different investigation paths, and separate build/diagnosis skills. Do not satisfy a task-count target by hiding several unrelated repairs in one numbered item.

Each lab must start independently. Seed supporting resources in a working state and introduce only the assigned fault or missing configuration. If an incident naturally requires several related changes, preserve that relationship rather than splitting it mechanically.

Keep integration work in capstones unless the user asks to restructure them too. Short labs prepare learners for the capstone; they do not need to repeat its whole stack or incident.

When cloning a lab, remove unrelated faults, waits, scripts, constraints and documentation. Preserve existing identifiers where changing them would break published references; give new labs unique runtime identities. Prefer the smallest environment that still proves the outcome.

## Rewrite the teaching with the assessment

Place each lab immediately after the reading that prepares it. Keep the outline, course navigation, learning objectives, summaries, prerequisites and lab titles consistent.

A useful lesson develops one concrete case:

1. Explain what the learner observes and which component is responsible.
2. Teach the concepts and fields needed to investigate it.
3. Show a runnable inspection and a bounded change.
4. Explain the evidence that establishes success and the limits of that evidence.

Write connected prose in plain English. Define an unfamiliar term where it first matters. Use technical resource names consistently; avoid fictional roles and metaphors that obscure what the system does. Keep examples close to the lab without silently turning the reading into an answer for a different environment.

When splitting pages, restore any shell functions, variables, port-forwards, files or prerequisite state that the extracted text depends on. State whether commands run in the playground or an independent lab. Do not assume the preceding lab is still running. Follow the local convention for pausing, starting, renewing and cleaning up environments.

For configuration examples, normally show a named file and its contents before the apply command. Explain the expected fields or behavior. Use captured output only when it was actually observed; label shortened or illustrative output accurately. Never invent a successful test transcript.

Keep a lesson's pitfalls specific to the operation. Use a short diagram when it explains ownership, data flow or state transitions better than another paragraph. Follow local conventions for headings, links and diagrams rather than exporting one project's markup rules to every course.

Check technical claims against the repository's pinned versions and primary documentation when needed. Update version inventories and existing synchronization tooling instead of scattering new version strings.

## Make grading prove the task

Grade the running behavior wherever possible: discovered endpoints, returned series, delivered requests, linked traces, deployed revisions, or evidence calculated from live data. A file existing or a command exiting successfully rarely proves the intended skill.

Check the constraints that distinguish a repair from a bypass. Depending on the task, reject disabled checks, deleted workloads, constant metric answers, removed admission controls, or changes to unrelated resources. Accept equivalent valid implementations unless the taught mechanism is itself part of the assessment.

For submitted measurements, validate their source identifiers, population, units, completeness and numeric validity. Recompute expected values from the current environment. Reject missing entries, stale evidence, non-finite numbers and a correct average built from incorrect individual measurements. Do not grade against one captured run's incidental values.

Allow bounded time for reconciliation and eventual telemetry. Select current, non-terminating resources when rollouts can leave old pods visible. Distinguish an infrastructure or API error from a deliberate grading failure.

## Verify automatically

Give each lab a reproducible lifecycle test:

1. Bootstrap a fresh environment and assert the intended starting state.
2. Confirm that unfinished work fails the relevant grader for the intended reason.
3. Apply the reference solution.
4. Wait for the required runtime state or telemetry with a timeout.
5. Run all graders and clean up the test environment.

Add focused regression tests for meaningful grader failure cases, especially calculations, stale evidence and bypasses. Avoid tests that merely repeat implementation strings or require identical wording in prose.

Integrate new labs into the repository's CI discovery or matrix. Keep the final required check dependent on discovery and every selected environment. Preserve diagnostics and test reports on failure. Include structural checks for unique environments, valid references, lab registration, teaching order and the agreed task range when they can prevent real regressions.

Run the checks appropriate to the change. Fix authored failures and rerun the affected tests. Report external infrastructure failures separately. A queued workflow or static validation is not a passing lifecycle test; state exactly what ran and what remains unverified.

## Preserve the reusable decisions

Update the repository's authoring guidance with the agreed structure, coverage rule, verification contract and CI requirements. Remove obsolete pilot restrictions when the user has authorized expansion. Keep project paths, runtime schemas, naming, version pins and renderer markers in project guidance rather than this generic skill.

Before handing over, inspect the complete diff for stale combined-lab wording, orphaned files, broken references and mismatches between tasks and graders. Summarize the resulting scope, actual validation and material limitations. Commit, publish or open a pull request only within the user's authorization.

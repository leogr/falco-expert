# Status comment templates

Public comments on the tracking issue are ghost-written for the maintainer. Take `<opener>`, `<closer>`, the update marker `<update>`, and the emoji slots from the maintainer's voice skill when one is available. Neutral defaults: `<opener>` = `Status update 👇`, `<closer>` = `Thanks 🙏`, `<update>` = `UPDATE:`, celebration slot `🚀`. Never write today's date in a comment (the UI shows it). References go in a sub-list, one per line. No `cc` or pings unless the maintainer asked for them in this comment. Draft into a file under `OUTPUT_DIR`, show it, post on the go with `--body-file`, fetch it back and compare.

## Recap (end of an active day or week)

```markdown
<opener>

- <component> `<version>` released <celebration> (<one line: what it carries>)
- <component>: <one line of state>; waiting for a second review
  - <pr-url>
  - <pr-url>
- <component>: <n> items left, tag by <weekday> at the latest; the driver tag depends on
  - <pr-url>
- <component>: no release needed for now; this may change if we merge
  - <pr-url>
- <consumer>: milestone and release notes cleaned up; the breaking change to call out is `<what>`
- Next: <upstream tag>, then <library and driver tags>, <rules releases>, and the final pin PR

The checklist above is up to date. The release date is still on track.
```

## Candidate announcement

```markdown
<Component> `<candidate>` is out 👉 <release-url>

It ships <library> `<version>` and driver `<driver-version>`, <cli-tool> `<version>`, <plugin> `<version>`, and rules `<version>`.

Please give it a try and report anything odd here <closer-emoji>
- container image `<registry>/<image>:<candidate>`
- DEB packages 👉 <dev-bucket-url>
- RPM packages 👉 <dev-bucket-url>

N.B. The final `<version>` will move to <what still changes>. <or: This is expected to be the last candidate before `<version>`.>
```

## Freeze

```markdown
<update> the `<version>` milestone is completed at the moment, so the code freeze is reached <celebration>

From now on, only fixes will be cherry-picked onto `<release-branch>`. The only planned change left is <the final pins>.
```

## Delay notice

```markdown
<opener>

- `<candidate>` is out 👉 <release-url>
- it ships <what changed since the previous candidate>
- <parallel item state, pointer to the checklist>

Also, the final release may be delayed by a few days, since:

- <abstract reason: deeper testing of late fixes>
- <abstract reason: infrastructure work in progress; no release until it is settled>

<closer>
```

## Pre-tag announcement

```markdown
Cutting `<version>` now from `<release-branch>` <celebration> No other change lands on the branch until the release is out.
```

## Tested comment on a fix PR

```markdown
<update> tested end to end on `<candidate>` (<what was tested, counts>). Follow-up 👉 <issue-url>. Cherry-picked in
- <sync-pr-url>
```

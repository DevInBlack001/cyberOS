# Branch: `docs/handbook`

**State:** planned · **Owner:** docs owner

## Charter

The student-facing and maintainer-facing writing. `README.md` currently does both jobs and
is getting long.

## Scope

| Path | Role |
|---|---|
| `README.md` | what CyberOS is, how to build it — for someone who found the repo |
| `docs/SPEC.md` | the normative specification |
| `docs/branches/` | branch charters |
| `docs/student-guide.md` | install, first login, keybinds, theme toggle, app store |
| `docs/maintainer-guide.md` | channel promotion, submission review, release procedure |
| `docs/troubleshooting.md` | safe graphics, `linux-lts` recovery, Secure Boot, wifi |

## The rules that define this branch

- **No email addresses.** They were deliberately removed from `README.md`; do not put them
  back. Contact goes through GitHub.
- Documented commands must have been run. A `docs/` PR that adds an untested command is
  rejected — this repo has already shipped a confidently-wrong claim about a reboot hang
  that turned out to be a keyboard-focus problem.
- Every branch charter is added in the same commit as that branch's first piece of work.

## Backlog

- A troubleshooting page is a prerequisite for handing the image to students. The three
  entries above cover the failures already predicted by the hardware tiers.
- `docs/student-guide.md` should be short enough to print on two sides.

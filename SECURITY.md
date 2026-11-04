# Security Policy

## Supported versions

NotDefteri has no versioned releases yet. Only the latest commit on the `main` branch is
supported. Fixes land on `main`; please reproduce issues against it before reporting.

| Version            | Supported |
|--------------------|-----------|
| `main` (latest)    | Yes       |
| Older commits      | No        |

## Reporting a vulnerability

**Please do not open a public issue for security problems.**

Report privately by email to **olcay.alkan035@gmail.com** with the subject line
`[NotDefteri security]`.

Please include:

- What the problem is and what an attacker could do with it
- Steps to reproduce, ideally with a sample note or folder that triggers it
- Platform and version (macOS version, or Linux distribution and GTK version)
- The commit you tested (`git rev-parse HEAD`)

## What to expect

- Acknowledgement within 7 days.
- An assessment and, if confirmed, a plan for a fix within 30 days.
- Credit in `CHANGELOG.md`, unless you prefer to stay anonymous.

This is a small personal project maintained in spare time, so these are targets, not guarantees.
Please give a reasonable time for a fix before disclosing publicly.

## Scope

NotDefteri is a local, offline notebook. It makes no network requests and stores notes as plain
files under `~/Documents/NotDefteri/`. Issues that are in scope include:

- A crafted note, image or folder that makes the app read, write or delete files outside the
  notes folder (for example through path traversal in page links, attachments or page moves)
- A crafted note that causes data loss or corruption of other notes
- Opening a link or attached file in a note that runs code or a command without the user's
  explicit action
- Problems in the "launch at login" entry the app writes
  (`~/Library/LaunchAgents` on macOS, `~/.config/autostart` on Linux)

Out of scope:

- Attacks that already require write access to your user account or notes folder beyond
  placing a note there
- The app being unsigned and distributed as a bare binary (a known limitation)
- Crashes with no security impact; please report these as normal
  [issues](https://github.com/olcayalkan/NotDefteri/issues)

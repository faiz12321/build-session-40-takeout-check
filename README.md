# Candidate sidecar names in a fictional Takeout-style folder

A read-only PowerShell 7.4+ filename-inventory lesson. Not a Google Takeout
validator, photo repair tool, metadata parser or backup product.
Use a new empty lesson folder, with PowerShell separately installed. Open pwsh,
not Windows PowerShell 5.1 or Command Prompt. Ubuntu requires /usr/bin/test.
Do not bypass execution-policy/security restrictions: use your normal approved
script workflow.

    ./make_sample.ps1
    ./takeoutcheck.ps1 report ./takeout-sample
    ./test_takeoutcheck.ps1

Setup exclusively creates seven fictional name fixtures in a NEW sample folder.
Existing paths, parent traversal and linked/reparse parents are refused.
The .jpg fixtures are plain text placeholders, not real media. A repeated setup
refuses instead of resetting the folder. Use a different new empty lesson folder
after an interrupted setup; do not delete existing data to force a retry.

## Narrow contract

Only same-directory case-sensitive filename candidates are considered. Classic
.json, .supplemental-metadata.json, a limited 46 UTF-16-code-unit stem cut and
observed duplicate-marker forms are recognized. These are limited observations,
not an official complete Google filename grammar. Multiple candidates or a
candidate claimed by multiple media names are ambiguous; no winner is guessed.
No media contents or JSON contents are read. Even invalid JSON can be a unique
candidate; a test demonstrates this limit. No dates are parsed or restored.
Unpaired JSON may be album metadata or an unsupported valid name, not missing
media. Selected extensions: jpg,jpeg,png,gif,mp4,mov,heic. Hidden names included.
Other valid files and naming patterns can be missed. Names are not proof of
readable media, correct metadata or a complete export.

Exit 0: all selected media and discovered JSON names have one-to-one recognized
candidates. Exit 1: missing/ambiguous/unpaired candidates or no selected media.
Exit 2: input refusal/error. None means a complete or valid Google export.

Input/ancestor links/reparse points, hardlinks, special entries and parent
traversal spellings are refused. At most 5000 entries processed; enumeration and
reporting can still use memory/time. Not a resource sandbox or hostile-race
boundary. Stop editors and sync. The checker contains no write code. Reports,
paths, filenames and errors can be private. No upload/network code is used;
cloud sync and other software are not controlled.

## Evidence

Two Windows full replays pass 31 checks (Unix pipe group skipped); two Ubuntu
replays pass 32 checks. Each platform pair is byte-identical. Displayed lesson
output is first Windows run. Tests cover wrong-folder borrowing, multiple/shared
candidates, invalid JSON, unknown names, unsafe inputs and the names/SHA256/
modification times of all seven fixtures before and after a report. Test and
recorder clean up only their own unique temporary trees. Symlink checks can skip
if permissions do not allow creating them. These are small fictional fixtures,
not real export, Windows desktop or complete naming-grammar validation.

Original checker could borrow JSON from another folder and fail to flag shared
candidates. This rewrite removes those guesses. Google explains that embedded
original media timestamps remain, while the operating system may assign a new
download timestamp, and added Google metadata is in secondary JSON. This lesson
does not inspect either source of dates. It does not claim JSON is the only real
date source or that filename coverage proves export completeness.

Lesson/source uses MIT. PowerShell and .NET are separately installed and carry
their own licenses; they are not bundled.

Sources:
- https://support.google.com/accounts/answer/3024190
- https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/issues/353
- https://github.com/ente/ente/commit/6d2c317877ea800b7d5e76c3fbd2ba89703c124d
- https://export.utillayer.com/guides/google-takeout-photos-metadata-sidecar

10 phone stages and three exact clipboard values pass at320/390/1280,
with no page overflow or JavaScript errors. Actual pixels inspected.

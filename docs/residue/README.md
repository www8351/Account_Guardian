# Residue

Artifacts from a deleted prior project, quarantined rather than destroyed.

Standing principle (owner ruling 2026-07-29): lock artifacts are never deleted, only
quarantined. Deleting a lock artifact is the exact bypass this product exists to
prevent, so it is never done as housekeeping.

## state_1200252169.dat.residue

Moved 2026-07-29 out of the terminal's Common files folder
(`Common\Files\AccountGuardian\state_1200252169.dat`), which is now empty.
Written 2026-07-27 by a prior, unrelated implementation. Never read beyond its
header fields, which were logged when it was found: format version, account,
state, reason, locked_at, locked_until, saved_at, crc.

It never collided with this project: SPEC v0.1 places our state file in the
terminal-local files folder, not the Common one. Kept here as evidence, not as
input. Nothing in this build derives from it.

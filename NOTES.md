# NOTES.md

Running journal. Every agent turn appends one line in this format:

```
<ISO-8601 timestamp> | <stage|area> | <what changed> | <result/anchor>
```

This is the audit trail. Don't summarize, don't reformat older
entries, don't delete. New entries go at the bottom. See
`docs/WORKFLOW.md` §4 for the discipline and §7 for how this is
used in the blocker protocol.

When a session is BLOCKED, the format is:

```
<ISO-8601 timestamp> | BLOCKED | <stage> | <command attempted; exact error; what would unblock>
```

---

<!-- entries below -->

# Global knowledge-capture trigger

Apply this rule across workspaces when a technical task produces a reusable lesson.

## Detection

After the current problem is solved and verified, consider a capture suggestion when there is:

- a reproducible bug or non-obvious root cause;
- an environment, configuration, version, or toolchain compatibility issue;
- a troubleshooting sequence that is likely to be useful again;
- a lesson that can transfer to another project;
- an explicit user request to remember or write something to the blog.

Do not suggest capture for a one-time typo, trivial path mistake, unverified guess, or information that cannot be safely generalized.

## Three-stage boundary

Before the user confirms capture, do not load `$knowledge-capture`, inspect the blog knowledge base, read blog-specific files, or create or modify files outside the current task's requested scope.

When a verified lesson is worth preserving, make one concise suggestion containing a possible title, the core reason, and a few keywords. Use only facts already established in the current task. Do not repeat the suggestion after the user declines.

If the user confirms the suggestion, or directly asks to write the lesson to the blog, explicitly activate `$knowledge-capture`. The Skill owns blog search, duplicate detection, redaction, draft creation, and validation. Do not perform those steps in this global rule.

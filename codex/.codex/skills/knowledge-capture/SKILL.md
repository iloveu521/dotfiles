---
name: knowledge-capture
description: Use when a technical task reveals a reproducible bug, non-obvious fix, environment or configuration issue, compatibility problem, or other reusable engineering lesson.
---

# Capture a reusable lesson as a blog draft

Use this Skill only after the user has explicitly confirmed that the verified lesson should be recorded, or has directly asked to write it to the blog. If that confirmation is absent, stop and return control to the lightweight suggestion stage; do not inspect the blog or create files.

## Blog root

Use the default blog root `$HOME/workspace/blog/hugo/dev`, expanding `$HOME` before access. If the user's blog is stored elsewhere, use the explicitly confirmed blog root instead of guessing.

```text
$HOME/workspace/blog/hugo/dev
```

Verify that it exists and is a directory. Read its `AGENTS.md` before making any change. If the root or project rules are unavailable, report the blocker instead of guessing the blog conventions.

## Workflow

1. Collect only the verified facts from the current task: symptom, environment, relevant error, investigation, root cause, fix, and validation evidence. Keep hypotheses explicitly labeled.
2. Search before writing with `rg` over existing files in `content/bugs`, `content/post`, `content/projects`, and `content/notes` when those directories exist. Search distinctive error text, component names, versions, commands, and configuration keys.
3. If a sufficiently similar article exists, do not create a duplicate and do not edit the existing article by default. Report the match and suggest what new evidence could be appended if the user wants an update.
4. Otherwise create one new file at `content/bugs/<category>/<slug>/index.md` using the repository's existing TOML front matter delimited by `+++`, with `draft = true`. Follow nearby articles for fields such as `categories` and `series`. Use a Chinese title and include these sections: `问题现象`, `环境信息`, `错误信息`, `排查过程`, `根本原因`, `解决方案`, `验证结果`, `经验总结`, and `相关内容`.
5. Remove or generalize passwords, API keys, tokens, cookies, private addresses, personal identifiers, and unnecessary machine-specific paths. Preserve an error only when it remains useful and safe.
6. Validate the new file's front matter, Markdown structure, slug, links, and `draft = true`. Run an available Hugo content/build check when practical; do not publish or deploy.

## Boundaries

- Do not modify, merge, rename, or delete existing articles unless the user explicitly requests that exact change.
- Do not turn an unverified guess into a root cause or solution.
- Do not commit or publish automatically.
- Report the absolute path of a created draft and any unresolved uncertainty.

# Blog project rules

This repository is a Hugo blog and a long-term technical knowledge base. These rules apply within this Hugo repository.

## Content layout

- Existing regular posts are under `content/post/` (singular).
- Reusable bug records belong under `content/bugs/<category>/`.
- Existing bug categories include `code-server`, `ros2`, `stm32`, and `ubuntu`; reuse a suitable category before creating another one.
- Project-specific notes belong under `content/projects/`.
- Do not assume a directory exists; inspect it before searching or writing.

## Article format

- Follow nearby articles before choosing front matter fields.
- Existing articles use TOML front matter delimited by `+++`; do not convert them to YAML.
- New knowledge-capture drafts must use `draft = true`.
- Use a clear Chinese title and meaningful categories or series consistent with existing articles, normally `Issue` and `Resolved` for a verified Bug record.
- A Bug record should explain the symptom, environment, error, investigation, root cause, solution, verification, and reusable lesson.
- Keep observed facts, hypotheses, and verified conclusions distinct.

## Safe changes

- Search existing articles before creating a new one.
- Do not silently edit, merge, rename, delete, publish, or deploy existing content.
- Remove secrets, tokens, cookies, private identifiers, and unnecessary machine-specific paths from copied logs.
- Preserve the existing `_CLAUDE.md`; this `AGENTS.md` is the Codex project rule.

## Validation

- Check front matter and Markdown structure after writing.
- Keep new capture articles as drafts until the user publishes them.
- Run an available Hugo content/build check when practical, without publishing or deploying.

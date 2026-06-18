---
description: student-theses-review スキルで組織リポを走査し、更新レビューと issue 対応を行う
---

# 学生リポ走査（student-theses-review）

**スラッシュ名**: `/student-theses-review`  
**スキル名**: `student-theses-review`

## エージェントがすること

### 1. スキル正本を読む（必須）

次のパスを順に探し、見つかった `SKILL.md` を読む:

1. `<STUDENT_THESES_ROOT>/a23036-fujiwara-kazumasa-student-theses-review-skill/skills/student-theses-review/SKILL.md`
2. `~/.cursor/skills/student-theses-review/SKILL.md`
3. `~/.claude/skills/student-theses-review/SKILL.md`

### 2. パスを決める

- `STUDENT_THESES_ROOT`: student-theses ワークスペースルート（`bin/refresh-org.sh` があるディレクトリ）
- `SKILL_DIR`: 上記 `SKILL.md` の親ディレクトリ

### 3. 走査を実行

```bash
bash "$SKILL_DIR/scripts/run-review.sh" \
  -r "$STUDENT_THESES_ROOT" --json
```

- stdout の JSON をパースし、`next_actions` を**上から順に**実行
- 全件 `bin/refresh-org.sh` は使わない（遅い）

### 4. `next_actions` の種別

| プレフィックス | 作業 |
|---------------|------|
| `verify_and_reply_issue:` | 学生コメントを検証し `gh issue comment`（自動 close 禁止） |
| `review_repo:` | 差分レビュー → issue 起票/コメント |
| `clone_repo:` | `gh repo clone fujiwara-kazumasa-ryukokou-lab/<name> "$STUDENT_THESES_ROOT/<name>"` |

### 5. レビュー完了後（各 `review_repo`）

```bash
bash "$SKILL_DIR/scripts/mark-reviewed.sh" -r "$STUDENT_THESES_ROOT" <repo-name>
```

### 6. 結果報告

日本語、冒頭に信頼度（%）。以下を含める:

- `pending_issues` の対処結果
- `updated_repos` のレビュー結果
- 起票・コメントした issue URL
- 問題なしと判断したリポ

## 制約

- org: `fujiwara-kazumasa-ryukokou-lab`
- 除外: `a23036*`、`archive`
- 学生の「直しました」はコミット検証後のみ返信
- `Closes #` / `Fixes #` 禁止
- issue close は指導者確認後のみ
- commit はユーザー明示時のみ

## スキル内 references（`SKILL_DIR/references/`）

- `review-checklist.md` — レビュー観点
- `issue-decision.md` — 起票判断
- `issue-student-response.md` — 学生コメント返信
- `issue-body-template.md` — issue 本文テンプレ

外部スキル: **github-agent-issue**, **gh-issue-lifecycle-policy**

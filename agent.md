# 学生リポレビュー エージェントガイド

エージェント向けの入口ファイルです。手順の正本は [`skills/student-theses-review/SKILL.md`](skills/student-theses-review/SKILL.md) を参照してください。

別環境用テンプレ: [`skills/student-theses-review/references/agent.md.template`](skills/student-theses-review/references/agent.md.template)  
展開コマンド: `bash skills/student-theses-review/scripts/install-agent-md.sh -r <STUDENT_THESES_ROOT>`

Cursor スラッシュコマンド: `/student-theses-review`  
インストール: `bash skills/student-theses-review/scripts/install-slash-command.sh -r <STUDENT_THESES_ROOT>`

## 役割分担

| ファイル | 対象 | 内容 |
|---------|------|------|
| **このファイル (`agent.md`)** | エージェント | 1 画面の索引・作業フロー |
| **`skills/student-theses-review/`** | エージェント | 詳細手順・スクリプト・references の正本 |
| **`README.md`** | 人間 | インストール・配布 |

## いつこのスキルを使うか

- 学生 org リポの**更新分取得とレビュー**
- 問題の **GitHub Issue 起票**（または既存 issue へのコメント）
- 学生の **issue コメントへの返信**（修正報告の検証含む）

対象 org: `fujiwara-kazumasa-ryukokou-lab`  
除外: リポ名が `a23036` で始まるもの、`archive`（`EXCLUDE_REPOS` で追加可）

## 作業フロー（必須）

### 1. オーケストレーション

```bash
STUDENT_THESES_ROOT=/path/to/student-theses \
bash skills/student-theses-review/scripts/run-review.sh \
  -r /path/to/student-theses --json
```

- 人間向けログは stderr、**`--json` の stdout をパース**して `next_actions` を得る
- 全件 `student-theses/bin/refresh-org.sh` は遅いため、通常は使わない

### 2. `next_actions` を上から実行

| アクション | 参照先 |
|-----------|--------|
| `verify_and_reply_issue: …` | [issue-student-response.md](skills/student-theses-review/references/issue-student-response.md) |
| `review_repo: …` | [review-checklist.md](skills/student-theses-review/references/review-checklist.md) + [issue-decision.md](skills/student-theses-review/references/issue-decision.md) |
| `clone_repo: …` | `gh repo clone fujiwara-kazumasa-ryukokou-lab/<name> $STUDENT_THESES_ROOT/<name>` |

### 3. Issue 起票・返信

- 本文テンプレ: [issue-body-template.md](skills/student-theses-review/references/issue-body-template.md)
- `gh issue create` は **`--body-file` 推奨**
- commit / PR に **`Closes #` / `Fixes #` を書かない**

### 4. レビュー済み記録

```bash
bash skills/student-theses-review/scripts/mark-reviewed.sh \
  -r /path/to/student-theses <repo-name>
```

状態ファイル: `<STUDENT_THESES_ROOT>/log/review-state.json`

## 作業別の参照先

| 作業 | 参照先 |
|------|--------|
| スキル全体（正本） | [skills/student-theses-review/SKILL.md](skills/student-theses-review/SKILL.md) |
| 一括実行 | [scripts/run-review.sh](skills/student-theses-review/scripts/run-review.sh) |
| 未返信 issue 一覧 | [scripts/list-pending-issue-responses.sh](skills/student-theses-review/scripts/list-pending-issue-responses.sh) |
| 高速 fetch | [scripts/fetch-recent-updates.sh](skills/student-theses-review/scripts/fetch-recent-updates.sh) |
| Issue 作法（外部） | **github-agent-issue** スキル |
| Issue close 方針（外部） | **gh-issue-lifecycle-policy** スキル |

## 作業前チェック

- [ ] `gh auth status` が成功する
- [ ] `jq` が使える
- [ ] `STUDENT_THESES_ROOT` を **`-r` で明示**した（推定に頼らない）
- [ ] 応答は**日本語**、冒頭に**信頼度（%）**（90% 未満なら確認）
- [ ] 学生の「直しました」は**コミット検証後**にのみ返信
- [ ] issue の close は**指導者確認後**（エージェントが勝手に close しない）
- [ ] **commit はユーザーの明示指示があるときのみ**

## 環境変数（よく使う）

| 変数 | 既定 | 説明 |
|------|------|------|
| `STUDENT_THESES_ROOT` | — | 学生リポ clone 先（**必須推奨**） |
| `ORG` | `fujiwara-kazumasa-ryukokou-lab` | 対象 org |
| `EXCLUDE_PREFIX` | `a23036` | レビュー除外プレフィックス |
| `EXCLUDE_REPOS` | `archive` | 除外リポ（カンマ区切り） |
| `SUPERVISOR_LOGINS` | `KazumasaFUJIWARA` | 指導者 GitHub ログイン |

## student-theses ワークスペースから使う場合

スキルリポが `student-theses/a23036-fujiwara-kazumasa-student-theses-review-skill/` にあるとき:

```bash
SKILL_ROOT=/path/to/student-theses/a23036-fujiwara-kazumasa-student-theses-review-skill
STUDENT_THESES_ROOT=/path/to/student-theses

bash "$SKILL_ROOT/skills/student-theses-review/scripts/run-review.sh" \
  -r "$STUDENT_THESES_ROOT" --json
```

グローバルインストール済みの場合は `skills/student-theses-review/scripts/...` をそのまま参照できる。

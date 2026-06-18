---
name: student-theses-review
description: >-
  fujiwara-kazumasa-ryukokou-lab 組織の学生リポを run-review.sh で一括同期し、a23036 以外を
  レビューして Issue 化・学生コメント返信する。Use when 更新分取得、卒論レビュー、student-theses、
  issue 起票、issue 返信、指導レビュー。
triggers:
  - 更新分
  - 卒論レビュー
  - student-theses
  - refresh-org
  - 学生リポ
  - issue 起票
  - issue 返信
  - 学生コメント
---

# 学生リポジトリ更新レビュー

`fujiwara-kazumasa-ryukokou-lab` 組織の学生研究リポについて、**更新分を取得**し、**a23036 系リポを除く**更新をレビューする。問題があれば **GitHub Issue で指摘**する。**学生の issue コメント**は検証して返信する。

## エージェント向けクイックスタート

**まずこれを1本実行**（人間向けログ + `--json` で機械可読サマリ）:

```bash
STUDENT_THESES_ROOT=/path/to/student-theses \
bash skills/student-theses-review/scripts/run-review.sh \
  -r /path/to/student-theses --json
```

`next_actions` を上から順に実行する。

| `next_actions` の例 | やること |
|---------------------|----------|
| `verify_and_reply_issue: repo#N` | [issue-student-response.md](references/issue-student-response.md) |
| `review_repo: name (sha)` | 差分レビュー → issue 起票/コメント |
| `clone_repo: name` | `gh repo clone ORG/name` または `refresh-org.sh` |

レビュー完了後:

```bash
bash skills/student-theses-review/scripts/mark-reviewed.sh -r /path/to/student-theses <repo-name>
```

## いつ使うか

- 「更新分を取得してレビューして issue で指摘」
- 「issue に学生が返信してきたので確認して」
- 定期的な学生リポのドキュメント・実装レビュー

## 前提

| 項目 | 内容 |
|------|------|
| `gh` | 認証済み |
| `jq` | インストール済み |
| `STUDENT_THESES_ROOT` | org リポの clone 先（**`-r` で明示推奨**） |
| 除外 | `EXCLUDE_PREFIX`（既定 `a23036`）+ `EXCLUDE_REPOS`（既定 `archive`） |
| 応答言語 | 日本語 |
| 信頼度 | 回答冒頭に信頼度（%）。90% 未満なら確認 |

## 手順（詳細）

### 1. オーケストレーション

[scripts/run-review.sh](scripts/run-review.sh) が以下をまとめて実行する:

1. 未対応の学生 issue コメント検出
2. 直近 push リポの fetch
3. `next_actions` 付き JSON サマリ出力

### 2. 学生 issue コメント（PENDING がある場合）

[references/issue-student-response.md](references/issue-student-response.md)

- 「直しました」は **必ずコミットを検証**してから `gh issue comment`
- **自動 close しない**（**gh-issue-lifecycle-policy**）

### 3. 更新リポのレビュー（UPDATED がある場合）

各 `updated_repos[]` について:

1. `git -C $ROOT/<name> log --oneline <before>..<after>`
2. `git diff <before>..<after> --stat` または主要ファイルを読む
3. `gh issue list --repo ORG/<name> --state all`
4. [references/review-checklist.md](references/review-checklist.md)
5. 前回 SHA は `$ROOT/log/review-state.json` を参照（あれば `<last>..HEAD` に絞る）

### 4. Issue 化

[references/issue-decision.md](references/issue-decision.md)  
本文テンプレ: [references/issue-body-template.md](references/issue-body-template.md)  
詳細作法: **github-agent-issue** スキル

```bash
gh issue create --repo ORG/REPO --title "[doc] …" --body-file /tmp/issue-body.md
```

### 5. レビュー済み記録

```bash
mark-reviewed.sh -r $STUDENT_THESES_ROOT <repo-name> [sha]
```

### 6. 結果報告

- `pending_issues` の対処結果
- `updated_repos` のレビュー結果
- 起票・コメントした issue URL
- `mark-reviewed` したリポ

## 環境変数

| 変数 | 既定 | 説明 |
|------|------|------|
| `ORG` | `fujiwara-kazumasa-ryukokou-lab` | GitHub 組織 |
| `STUDENT_THESES_ROOT` | （要指定推奨） | clone 先ルート |
| `EXCLUDE_PREFIX` | `a23036` | 除外プレフィックス |
| `EXCLUDE_REPOS` | `archive` | 除外リポ（カンマ区切り） |
| `DAYS` | `14` | push 遡り日数 |
| `ISSUE_DAYS` | `30` | issue 遡り日数 |
| `LIMIT` | `50` | `gh repo list` 上限 |
| `GIT_TIMEOUT` | `45` | fetch タイムアウト秒 |
| `SUPERVISOR_LOGINS` | `KazumasaFUJIWARA` | 指導者ログイン |

## 依存スキル

- **github-agent-issue**: Issue 作法（未インストール時は `issue-body-template.md` を使用）
- **gh-issue-lifecycle-policy**: `Closes #` 禁止

## 関連スクリプト

| スクリプト | 役割 |
|------------|------|
| [scripts/run-review.sh](scripts/run-review.sh) | **メイン入口**（推奨） |
| [scripts/mark-reviewed.sh](scripts/mark-reviewed.sh) | レビュー済み SHA 記録 |
| [scripts/list-pending-issue-responses.sh](scripts/list-pending-issue-responses.sh) | 未返信 issue 一覧 |
| [scripts/fetch-recent-updates.sh](scripts/fetch-recent-updates.sh) | 高速 fetch |
| [scripts/list-review-targets.sh](scripts/list-review-targets.sh) | 対象リポ一覧 |
| [scripts/lib/common.sh](scripts/lib/common.sh) | 共通設定・関数 |
| [scripts/install-agent-md.sh](scripts/install-agent-md.sh) | `agent.md` をワークスペースへ展開 |
| [scripts/install-slash-command.sh](scripts/install-slash-command.sh) | `/student-theses-review` を Cursor へ配置 |
| [references/agent.md.template](references/agent.md.template) | ルート `agent.md` のポータブルテンプレ |

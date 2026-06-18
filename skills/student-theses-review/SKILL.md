---
name: student-theses-review
description: >-
  fujiwara-kazumasa-ryukokou-lab 組織の学生リポを高速同期し、a23036 以外の更新をレビューして
  問題を GitHub Issue で指摘する。学生の issue コメントへの返信・検証も行う。
  Use when 更新分取得、卒論レビュー、学生リポ、refresh-org、student-theses、
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

`fujiwara-kazumasa-ryukokou-lab` 組織の学生研究リポについて、**更新分を取得**し、**a23036 系リポを除く**更新をレビューする。問題があれば **GitHub Issue で指摘**する。あわせて、**学生が issue にコメントした場合は内容を検証し返信**する。

## いつ使うか

- 「更新分を取得してレビューして issue で指摘」
- 「issue に学生が返信してきたので確認して」
- 定期的な学生リポのドキュメント・実装レビュー
- `refresh-org.sh` 全件同期が遅いときの代替フロー

## 前提

| 項目 | 内容 |
|------|------|
| `gh` | 認証済み（`gh auth status` 成功） |
| ワークスペース | `<STUDENT_THESES_ROOT>` に org リポが clone 済み |
| 除外 | リポ名が `a23036` で始まるものはレビュー対象外 |
| 応答言語 | 日本語 |
| 信頼度 | 回答冒頭に信頼度（%）を示す。90% 未満なら処理を止め確認 |

## 手順（エージェント向け）

### 0. 学生 issue コメントの確認（毎回）

更新レビューの**前**に、未対応の学生コメントがないか確認する。

```bash
ORG=fujiwara-kazumasa-ryukokou-lab \
EXCLUDE_PREFIX=a23036 \
bash skills/student-theses-review/scripts/list-pending-issue-responses.sh
```

- `PENDING` がある → [references/issue-student-response.md](references/issue-student-response.md) に従い検証・返信
- 学生の「修正しました」は **必ずリポの差分で確認**してから返信
- issue の close は指導者確認後（**gh-issue-lifecycle-policy**）

### 1. 更新対象の特定（高速）

**全件 `refresh-org.sh` は WSL + `/mnt/d` 上で遅くなりやすい。** まず直近 push のリポだけを対象にする。

```bash
ORG=fujiwara-kazumasa-ryukokou-lab \
EXCLUDE_PREFIX=a23036 \
DAYS=14 \
bash skills/student-theses-review/scripts/list-review-targets.sh
```

### 2. 更新分の取得

```bash
STUDENT_THESES_ROOT=<clone先> \
ORG=fujiwara-kazumasa-ryukokou-lab \
EXCLUDE_PREFIX=a23036 \
GIT_TIMEOUT=45 \
bash skills/student-theses-review/scripts/fetch-recent-updates.sh
```

- `UPDATED` と表示されたリポのみレビューする
- `UPTODATE` はスキップ可
- 全件同期が必要なときだけ `student-theses/bin/refresh-org.sh` を使う（時間に余裕がある場合）

### 3. レビュー

各 `UPDATED` リポについて:

1. `git log --oneline -10` で直近コミットを把握
2. `git diff <before>..<after> --stat` または主要ファイルを読む
3. 既存 issue を確認: `gh issue list --repo <ORG>/<name> --state all`
4. [references/review-checklist.md](references/review-checklist.md) に沿って問題を洗い出す

### 4. Issue 化

[references/issue-decision.md](references/issue-decision.md) に従い:

- **既存 issue と同一論点** → `gh issue comment` で追記
- **新規論点** → `gh issue create --body-file` で起票
- **乱発しない**（重複・未確認の大量起票は避ける）

Issue 本文テンプレ・`gh` 作法は **github-agent-issue** スキルに従う。  
commit / PR 本文に `Closes #` / `Fixes #` は使わない（**gh-issue-lifecycle-policy**）。

```bash
gh issue create --repo <ORG>/<REPO> \
  --title "[doc] 短い要約" \
  --body-file /tmp/issue-body.md \
  -l documentation   # 存在するラベルのみ
```

### 5. 学生コメントへの返信（ステップ 0 で PENDING があった場合）

[references/issue-student-response.md](references/issue-student-response.md) に従う。

1. コメント全文を読む
2. 該当リポの最新コミットで修正を検証
3. `gh issue comment` で確認結果を返信（充足 / 未達を明記）
4. 全条件充足でも **自動 close しない**

### 6. 結果報告

ユーザーへ以下を簡潔に報告する:

- 学生 issue コメントの対処結果（PENDING 件数・返信 URL）
- 同期方法（高速 / 全件）
- 更新のあったリポ一覧（a23036 除外）
- 起票・コメントした issue URL
- 問題なしと判断したリポ

## 環境変数

| 変数 | 既定 | 説明 |
|------|------|------|
| `ORG` | `fujiwara-kazumasa-ryukokou-lab` | GitHub 組織 |
| `STUDENT_THESES_ROOT` | スクリプトから自動推定 | clone 先ルート |
| `EXCLUDE_PREFIX` | `a23036` | レビュー除外プレフィックス |
| `DAYS` | `14` | 直近何日以内の push を対象にするか |
| `LIMIT` | `30` | `gh repo list` の上限 |
| `GIT_TIMEOUT` | `45` | 1 リポあたり git fetch の秒数 |
| `SUPERVISOR_LOGINS` | `KazumasaFUJIWARA` | 指導者 GitHub ログイン（カンマ区切り） |

## 依存スキル

- **github-agent-issue**: Issue 本文テンプレ・`gh issue create` の作法
- **gh-issue-lifecycle-policy**: `Closes #` 禁止、手動 close の原則

## 関連スクリプト

| スクリプト | 役割 |
|------------|------|
| [scripts/list-review-targets.sh](scripts/list-review-targets.sh) | 直近 push かつ a23036 以外のリポ一覧 |
| [scripts/fetch-recent-updates.sh](scripts/fetch-recent-updates.sh) | 対象リポのみ `git fetch` + fast-forward |
| [scripts/list-pending-issue-responses.sh](scripts/list-pending-issue-responses.sh) | 未対応の学生 issue コメント一覧 |

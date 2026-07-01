# 学生活動クエリ（エージェント向け）

エージェントが「学生の様子は？」「誰が止まっている？」等を答えるときは、**推測せず** `query-student-activity.sh` を実行する。

## いつ使うか

- 学生の活動状況を一括把握したい
- 要レビュー・要返信・非活動リポを特定したい
- 特定学生（学籍ID）や特定リポの状態を確認したい
- レビュー作業の前に全体像を把握したい

## 実行

```bash
STUDENT_THESES_ROOT=/path/to/student-theses \
bash skills/student-theses-review/scripts/query-student-activity.sh \
  -r /path/to/student-theses -q summary
```

**stdout は常に JSON**。`answer` フィールドに日本語要約があるので、まずそれを読み、必要なら `items` / `repos` を詳細参照する。

## クエリ一覧

| `-q` | 用途 | 主な出力フィールド |
|------|------|-------------------|
| `status` | 全体スナップショット（**既定**） | `summary`, `repos`, `pending_issues`, `answer` |
| `summary` | 件数サマリのみ | `summary`, `answer` |
| `repos` | 全学生リポ一覧 | `items`, `count` |
| `needs_review` | 要レビュー・未レビュー | `items`, `count` |
| `pending_replies` | 指導者返信待ち issue | `items`, `count` |
| `inactive` | 長期間 push なし（idle） | `items`, `count` |
| `active` | 最近 push あり（active/recent） | `items`, `count` |
| `repo` | 単一リポ（`--repo` 必須） | `items[0]` |
| `student` | 学籍IDで検索（`--student-id` 必須） | `items` |

## 例

```bash
# 全体サマリ
query-student-activity.sh -r "$ROOT" -q summary

# 要レビューだけ
query-student-activity.sh -r "$ROOT" -q needs_review

# 特定リポ
query-student-activity.sh -r "$ROOT" -q repo --repo y220020-takagi-yuusuke-typing

# 特定学籍
query-student-activity.sh -r "$ROOT" -q student --student-id y230018
```

## フィールド意味

### `activity`

| 値 | 意味 |
|----|------|
| `active` | 直近 `ACTIVITY_ACTIVE_DAYS`（既定7日）以内に push |
| `recent` | 直近 `ACTIVITY_RECENT_DAYS`（既定14日）以内 |
| `stale` | 直近 `ACTIVITY_STALE_DAYS`（既定30日）以内 |
| `idle` | それより古い |

### `review_status`

| 値 | 意味 |
|----|------|
| `reviewed` | `review-state.json` の SHA と一致 |
| `needs_review` | ローカル HEAD または push 時刻がレビュー済みより新しい |
| `not_reviewed` | clone はあるがレビュー記録なし |
| `not_cloned` | ローカル未 clone |

### `clone_status`

| 値 | 意味 |
|----|------|
| `present` | `$ROOT/<repo>/.git` あり |
| `missing` | 未 clone |
| `unknown` | `STUDENT_THESES_ROOT` 未指定 |

## エージェントの答え方

1. スクリプトを実行し `answer` を要約として使う
2. ユーザーが特定学生を聞いたら `-q student --student-id` または `-q repo`
3. 作業優先度: `pending_replies` → `needs_review` → `run-review.sh`
4. 数値・リポ名は JSON から引用（推測しない）

## `run-review.sh` との使い分け

| スクリプト | 役割 |
|-----------|------|
| `query-student-activity.sh` | **読み取り専用**。現状把握・質問応答 |
| `run-review.sh` | fetch + レビュー対象検出 + `next_actions` 生成 |

活動確認だけなら query、実際にレビュー作業を始めるなら run-review。

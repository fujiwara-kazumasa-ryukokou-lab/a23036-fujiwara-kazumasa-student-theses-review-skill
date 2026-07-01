
## 2026-07-01T17:45:00+09:00

学生活動クエリスクリプト（エージェント向け）

- `query-student-activity.sh` 追加: 読み取り専用 JSON クエリ（status/summary/needs_review 等）
- `lib/activity-data.sh` 追加: リポ活動データ収集の共通ロジック
- `references/query-student-activity.md` 追加: エージェント利用ガイド
- SKILL.md / agent.md: 活動把握は query、レビュー作業は run-review と役割分担を明記
- issue-close-policy・install-issue-close-guard 等を同梱
- ターミナル用 show-dashboard.sh は採用せず削除（query 一本化）

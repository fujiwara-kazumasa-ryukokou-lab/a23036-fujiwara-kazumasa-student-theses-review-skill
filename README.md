# a23036-fujiwara-kazumasa-student-theses-review-skill

学生卒論・研究リポジトリ（`fujiwara-kazumasa-ryukokou-lab` 組織）の更新取得・レビュー・Issue 起票をエージェントが行うためのスキル正本。

## スキル

| スキル | 説明 |
|--------|------|
| [student-theses-review](skills/student-theses-review/SKILL.md) | `run-review.sh` で一括同期 → レビュー → Issue 化／学生コメント返信 |

## クイックスタート（エージェント）

```bash
STUDENT_THESES_ROOT=/path/to/student-theses \
bash skills/student-theses-review/scripts/run-review.sh -r /path/to/student-theses --json
```

`next_actions` を順に実行し、レビュー後は `mark-reviewed.sh` で記録する。

別マシンで `student-theses/agent.md` を置く場合:

```bash
bash skills/student-theses-review/scripts/install-agent-md.sh \
  -r /path/to/student-theses \
  -s /path/to/skills/student-theses-review   # gh skill install 先でも可
```

スラッシュコマンド `/student-theses-review`:

```bash
bash skills/student-theses-review/scripts/install-slash-command.sh -r /path/to/student-theses
# 全プロジェクト: --global
```

## 前提

- GitHub CLI (`gh`) ・ `jq` 認証済み
- ローカルに `student-theses` ワークスペース（`-r` でパス指定）

## インストール

```bash
gh skill install fujiwara-kazumasa-ryukokou-lab/a23036-fujiwara-kazumasa-student-theses-review-skill student-theses-review --agent cursor --scope user
gh skill install fujiwara-kazumasa-ryukokou-lab/a23036-fujiwara-kazumasa-student-theses-review-skill student-theses-review --agent claude-code --scope user
```

## ローカル試験

```bash
gh skill install --from-local skills/student-theses-review --agent cursor
```

## 配布

```bash
gh skill publish --tag vX.Y.Z
```

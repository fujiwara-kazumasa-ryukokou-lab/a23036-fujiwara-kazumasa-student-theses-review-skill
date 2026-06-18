# a23036-fujiwara-kazumasa-student-theses-review-skill

学生卒論・研究リポジトリ（`fujiwara-kazumasa-ryukokou-lab` 組織）の更新取得・レビュー・Issue 起票をエージェントが行うためのスキル正本。

## スキル

| スキル | 説明 |
|--------|------|
| [student-theses-review](skills/student-theses-review/SKILL.md) | 更新分取得 → a23036 以外をレビュー → Issue 化／学生コメントへの返信 |

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

## 前提

- GitHub CLI (`gh`) 認証済み
- ローカルに `student-theses` ワークスペース（組織リポの clone 先）があること

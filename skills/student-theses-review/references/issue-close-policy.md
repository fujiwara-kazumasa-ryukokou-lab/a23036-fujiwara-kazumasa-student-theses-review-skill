# Issue close 方針（指導者レビュー）

## 誰が close してよいか

| 主体 | close 可否 | 条件 |
|------|-----------|------|
| **指導者**（`SUPERVISOR_LOGINS`） | ✅ 可 | 受け入れ条件を確認した後 |
| **エージェント** | ✅ **可** | コミット検証で受け入れ条件が**すべて充足**しているとき。`gh issue close` を実行してよい |
| **学生** | ❌ **不可** | 指導者起票の issue を学生が close してはならない（修正報告はコメントのみ） |

## いつ close するか（エージェント）

1. レビューで受け入れ条件が**すべて充足**している
2. コミット検証済み（「直しました」は push されたコードで確認）
3. close 前に `gh issue comment` で確認結果を残す（未記載なら close 時コメントで可）

**充足している issue はエージェントがその場で close してよい。** 未達は open のまま。

```bash
gh issue close <N> --repo <ORG>/<REPO> \
  --comment "## 確認結果（指導者レビュー）

コミット \`<sha>\` を確認しました。受け入れ条件を充足しているため close します。"
```

### エージェントが close しない場合

- 受け入れ条件が一部未達
- push 未反映で検証不能
- 指導者が「close するな」と指示した場合

## `gh` で close できるか（設定）

**`gh` 専用の「エージェント close 許可」設定はない。** 次が揃っていれば `gh issue close` はそのまま使える。

| 要件 | 確認方法 |
|------|----------|
| 指導者アカウントで認証 | `gh auth status` → `SUPERVISOR_LOGINS` のいずれか |
| リポへの write 権限 | token に `repo` scope（既定の `gh auth login` で可） |
| 対象リポの指定 | `gh issue close N --repo ORG/REPO` |

```bash
gh auth status
gh issue close 1 --repo fujiwara-kazumasa-ryukokou-lab/<repo> --comment "…"
```

**学生の close 禁止**は `gh` 設定ではなく、別途 [GitHub Actions ガード](#推奨-issue-close-ガードgithub-actions) または運用（reopen）で対応する。

## 学生による close の禁止

### 運用ルール（必須）

- 学生に **commit / PR 本文へ `Closes #` / `Fixes #` を書かせない**（自動 close 防止）
- 学生には **issue へのコメントで修正報告**するよう案内する
- 指導者起票 issue を学生が close した場合は **reopen** し、理由をコメントする

### GitHub 標準機能だけでは完全には防げない

学生リポに **Write** 権限があると、GitHub 上は**他人が起票した issue も close できる**（権限の仕様）。  
「指導者起票のみ学生 close 禁止」という**ネイティブ設定はない**。

| 手段 | 効果 | 備考 |
|------|------|------|
| 運用ルール + エージェントが reopen | 中 | takagi で発生したパターンへの対処 |
| **GitHub Actions**（下記ワークフロー） | **高** | 学生が close しても自動 reopen。Write 権限を維持したまま enforce 可能 |
| 学生を **Triage** のみにする | 低 | push できなくなるため卒論リポでは非現実的 |

### 推奨: issue close ガード（GitHub Actions）

各学生リポ（または org 共通テンプレ）に配置する。

```bash
bash skills/student-theses-review/scripts/install-issue-close-guard.sh \
  -r /path/to/student-theses/<repo-name>
```

ワークフロー正本: [../.github/workflows/issue-close-guard.yml.template](../.github/workflows/issue-close-guard.yml.template)

動作:

1. issue が close された
2. closer が `SUPERVISOR_LOGINS` に含まれない
3. issue 起票者（author）が `SUPERVISOR_LOGINS` に含まれる
4. → **自動 reopen** + 説明コメント

指導者・エージェント（指導者 token の `gh`）が close した issue はそのまま閉じたまま。

## 関連

- [issue-student-response.md](issue-student-response.md) — 学生コメント検証
- **gh-issue-lifecycle-policy** — `Closes #` 禁止

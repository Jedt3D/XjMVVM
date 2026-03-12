---
title: タグと多対多
description: 2番目のリソース（Tags）を追加する方法、多対多結合テーブルをワイヤーアップする方法、リレーションシップ全体をクエリする方法。
---

# タグと多対多

Tags の追加により、2 つのことが同時に導入されました：**2 番目の完全なリソース**（CRUD パターンが Notes 以外にも一般化できることを証明する）と、結合テーブルを介した Notes と Tags の**多対多リレーションシップ**です。

## Tagリソース

`TagModel`は`NoteModel`と同じ3層パターンに従います。

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: right
#spacing: 48
#padding: 10
#lineWidth: 1.5
[DBAdapter] -> [BaseModel]
[BaseModel] -> [TagModel|TableName(): "tags"\nColumns(): id, name, created_at\nGetAll() / GetByID()\nCreate() / Update() / Delete()]
[TagModel] -> [<database> tags]
-->
<!-- ascii
DBAdapter → BaseModel → TagModel → tags table
TagModel declares: TableName="tags", Columns="id, name, created_at"
Methods: GetAll(), GetByID(), Create(), Update(), Delete()
-->
<!-- /diagram -->

```xojo
Protected Class TagModel
Inherits BaseModel

  Protected Function TableName() As String
    Return "tags"
  End Function

  Protected Function Columns() As String
    Return "id, name, created_at"
  End Function

  Function GetAll() As Variant()
    Return FindAll("name ASC")
  End Function

  Function GetByID(id As Integer) As Dictionary
    Return FindByID(id)
  End Function

  Function Create(name As String) As Integer
    Var db As SQLiteDatabase = OpenDB()
    db.ExecuteSQL("INSERT INTO tags (name) VALUES (?)", name)
    Var newID As Integer = db.LastRowID
    db.Close()
    Return newID
  End Function

  Sub Update(id As Integer, name As String)
    Var db As SQLiteDatabase = OpenDB()
    db.ExecuteSQL("UPDATE tags SET name = ? WHERE id = ?", name, id)
    db.Close()
  End Sub

  Sub Delete(id As Integer)
    DeleteByID(id)
  End Sub

End Class
```

スキーマは`DBAdapter.InitDB()`に登録されています：

```xojo
db.ExecuteSQL("CREATE TABLE IF NOT EXISTS tags (" + _
  "id          INTEGER PRIMARY KEY AUTOINCREMENT, " + _
  "name        TEXT NOT NULL, " + _
  "created_at  TEXT DEFAULT (datetime('now')))")
```

---

## Tagsルート

7つのルートが`App.Opening`に登録され、Notesパターンをミラーリングしています：

| Method | Path | ViewModel | Action |
|--------|------|-----------|--------|
| `GET` | `/tags` | `TagsListVM` | すべてのタグをリスト |
| `GET` | `/tags/new` | `TagsNewVM` | 新しいタグフォーム |
| `POST` | `/tags` | `TagsCreateVM` | タグを作成 |
| `GET` | `/tags/:id` | `TagsDetailVM` | タグを表示 |
| `GET` | `/tags/:id/edit` | `TagsEditVM` | フォームを編集 |
| `POST` | `/tags/:id` | `TagsUpdateVM` | タグを更新 |
| `POST` | `/tags/:id/delete` | `TagsDeleteVM` | タグを削除 |

---

## 多対多：note_tags

NotesとTagsは多対多リレーションシップを持っています。1つのnoteは多くのタグを持つことができます。1つのタグは多くのnoteに現れることができます。これは**結合テーブル**でモデル化されています — notesテーブルもtagsテーブルも外部キー列がありません。

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: right
#spacing: 44
#padding: 10
#lineWidth: 1.5
[<database> notes|id\ntitle\nbody\ncreated_at\nupdated_at] -- [note_tags|note_id (FK)\ntag_id (FK)\nPRIMARY KEY (note_id, tag_id)]
[note_tags] -- [<database> tags|id\nname\ncreated_at]
-->
<!-- ascii
notes (id, title, body, ...)
  │
  │  note_tags (note_id, tag_id)  ← junction / bridge table
  │
tags (id, name, created_at)

A note can have zero or many tags.
A tag can appear on zero or many notes.
-->
<!-- /diagram -->

スキーマ：

```xojo
db.ExecuteSQL("CREATE TABLE IF NOT EXISTS note_tags (" + _
  "note_id  INTEGER NOT NULL, " + _
  "tag_id   INTEGER NOT NULL, " + _
  "PRIMARY KEY (note_id, tag_id))")
```

複合主キー `(note_id, tag_id)` はデータベースレベルで一意性を強制します — ノートは同じタグと 2 回関連付けられることはありません。

---

## noteのタグの読み取り

`NoteModel.GetTagsForNote()`は`JOIN`で結合テーブルをクエリします：

```xojo
Function GetTagsForNote(noteID As Integer) As Variant()
  Var results() As Variant
  Var db As SQLiteDatabase = OpenDB()
  Var sql As String = "SELECT t.id, t.name, t.created_at FROM tags t " + _
    "JOIN note_tags nt ON nt.tag_id = t.id " + _
    "WHERE nt.note_id = ? ORDER BY t.name ASC"
  Var rs As RowSet = db.SelectSQL(sql, noteID)
  While Not rs.AfterLastRow
    Var row As New Dictionary()
    row.Value("id") = rs.Column("id").StringValue
    row.Value("name") = rs.Column("name").StringValue
    row.Value("created_at") = rs.Column("created_at").StringValue
    results.Add(row)
    rs.MoveToNextRow()
  Wend
  rs.Close()
  db.Close()
  Return results
End Function
```

戻り値は`Variant()`の`Dictionary`です — JinjaXテンプレートとJSON APIと完全に互換性があります。

---

## noteのタグの書き込み

`NoteModel.SetTagsForNote()` は**削除してから挿入する**パターンを使ってタグセット全体をアトミックに置き換えます:

```xojo
Sub SetTagsForNote(noteID As Integer, tagIDs() As Integer)
  Var db As SQLiteDatabase = OpenDB()
  db.ExecuteSQL("DELETE FROM note_tags WHERE note_id = ?", noteID)
  For Each tagID As Integer In tagIDs
    db.ExecuteSQL("INSERT OR IGNORE INTO note_tags (note_id, tag_id) VALUES (?, ?)", noteID, tagID)
  Next
  db.Close()
End Sub
```

!!! warning
    `INSERT OR IGNORE`は意図的です。複合主キーはデータベースレベルで重複を防ぎます。同じ`tagID`が配列に複数回現れる場合、`INSERT OR IGNORE`は制約エラーを発生させるのではなく、重複をサイレントにスキップします。

!!! note
    削除してから挿入するパターンはタグセット全体を一括で扱います — 古いセットと新しいセットを差分比較しません。シンプルで、ほとんどのユースケースで正しく機能します。各関連付けのメタデータ（例: タグ割り当てごとのタイムスタンプ）を保持する必要がある場合は、差分比較アプローチが必要です。

---

## 新しい多対多リレーションシップを追加

2番目の結合を追加するには（例：Note ↔ Category）：

**1.** `DBAdapter.InitDB()`に結合テーブルを追加：

```xojo
db.ExecuteSQL("CREATE TABLE IF NOT EXISTS note_categories (" + _
  "note_id      INTEGER NOT NULL, " + _
  "category_id  INTEGER NOT NULL, " + _
  "PRIMARY KEY (note_id, category_id))")
```

**2.** 同じ JOIN および削除-挿入パターンを使用して、`GetCategoriesForNote()` と `SetCategoriesForNote()` を関連するモデルに追加してください。

**3.** ノートの詳細または編集フォームをレンダリングする ViewModel で両方のメソッドを呼び出し、結果をコンテキスト Dictionary にマージしてください。

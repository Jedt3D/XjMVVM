---
title: SQLite & Dictionary コントラクト
description: SQLite で動作する方法、RowSet を Dictionary に変換する方法、スレッドセーフなモデルクラスを記述する方法。
---

# SQLite & Dictionary コントラクト

## コアパターン

すべてのモデルメソッドは同じパターンに従います: 新しいデータベース接続を開く、クエリを実行する、各 `RowSet` 行を `Dictionary` に変換する、すべてを閉じる、戻す。

このパターンは意図的です — スレッドセーフティを確保し、JinjaX が必要とする Dictionary データコントラクトを強制します。

```xojo
Function GetAll() As Variant()
  Var results() As Variant
  Var db As SQLiteDatabase = OpenDB()

  Var rs As RowSet = db.SelectSQL(
    "SELECT id, title, body, created_at, updated_at FROM notes ORDER BY updated_at DESC"
  )

  While Not rs.AfterLastRow
    Var row As New Dictionary()
    row.Value("id")         = rs.Column("id").IntegerValue
    row.Value("title")      = rs.Column("title").StringValue
    row.Value("body")       = rs.Column("body").StringValue
    row.Value("created_at") = rs.Column("created_at").StringValue
    row.Value("updated_at") = rs.Column("updated_at").StringValue
    results.Add(row)
    rs.MoveToNextRow()
  Wend

  rs.Close()
  db.Close()
  Return results
End Function
```

戻り型 `Variant()` を `Dictionary` オブジェクトを含むのは、JinjaX が `{% for %}` ループで反復できる唯一の形式です。

## 戻り型

| 操作 | 戻り型 | Nil ケース |
|---|---|---|
| 複数行 | `Variant()` (of `Dictionary`) | 空配列 `()` |
| 単一行 | `Dictionary` | `Nil` |
| 作成 | `Integer` (新しい行 ID) | — |
| 更新 / 削除 | `Sub` (なし) | — |

単一行をフェッチするときは常に `Nil` をチェック:

```xojo
// ViewModel で
Var note As Dictionary = NoteModel.GetByID(id)
If note = Nil Then
  RenderError(404, "Note not found")
  Return
End If
```

## リクエストごとのデータベース接続

プライベート `OpenDB()` メソッドはすべての呼び出しで **新しい** 接続を開きます。`App` に共有され、長期間保たれるデータベース接続はありません。

```xojo
Private Function OpenDB() As SQLiteDatabase
  Var dbFile As New FolderItem(DB_PATH, FolderItem.PathModes.Native)
  Var db As New SQLiteDatabase
  db.DatabaseFile = dbFile
  db.Connect()
  Return db
End Function
```

**なぜリクエストごと?** Xojo は複数のスレッドで同時リクエストを処理します。共有 `SQLiteDatabase` インスタンスはミューテックスが必要です。リクエストごとに新しい接続を開く方が簡単で、すべてのロック複雑さを避けます — SQLite は複数のプロセスからの同時読み取り接続をネイティブに処理します。

**なぜ接続プールではない?** このフレームワークが対象とするトラフィック量 (小チーム、内部ツール)、接続を開く際のオーバーヘッドは無視できます。プールはこのスケールでの測定可能な利点なしに複雑さを追加します。

## データベース初期化

アプリが起動するときに呼ばれる最初のメソッドは `NoteModel.InitDB()` (`App.Opening()` から) です。データベースファイルを作成し、`CREATE TABLE IF NOT EXISTS` を実行します:

```xojo
Shared Function InitDB() As SQLiteDatabase
  Var dbFile As New FolderItem(DB_PATH, FolderItem.PathModes.Native)
  Var db As New SQLiteDatabase
  db.DatabaseFile = dbFile

  If Not dbFile.Exists Then
    db.CreateDatabase()   // ファイルを作成
  Else
    db.Connect()
  End If

  db.ExecuteSQL("CREATE TABLE IF NOT EXISTS notes (" + _
    "id          INTEGER PRIMARY KEY AUTOINCREMENT, " + _
    "title       TEXT NOT NULL, " + _
    "body        TEXT, " + _
    "created_at  TEXT DEFAULT (datetime('now')), " + _
    "updated_at  TEXT DEFAULT (datetime('now')))")

  Return db
End Function
```

これは起動するたびに呼ぶのが安全です — `IF NOT EXISTS` はべき等です。

## パラメータ化されたクエリ

値には常に `?` プレースホルダーを使用します。ユーザー入力を SQL 文字列に連結しません — これは SQL インジェクションを防ぎます:

```xojo
// ✅ 正解 — パラメータ化
db.ExecuteSQL("INSERT INTO notes (title, body) VALUES (?, ?)", title, body)
db.SelectSQL("SELECT * FROM notes WHERE id = ?", id)

// ❌ 間違い — SQL インジェクションリスク
db.ExecuteSQL("INSERT INTO notes (title) VALUES ('" + title + "')")
```

`SelectSQL()` と `ExecuteSQL()` は SQL 文字列の後に可変数の `Variant` パラメータを受け入れます。

## 最後に挿入された行 ID を取得

`INSERT` の後、`db.LastRowID` を使用して新しい行の ID を取得:

```xojo
Function Create(title As String, body As String) As Integer
  Var db As SQLiteDatabase = OpenDB()
  db.ExecuteSQL("INSERT INTO notes (title, body) VALUES (?, ?)", title, body)
  Var newID As Integer = db.LastRowID
  db.Close()
  Return newID
End Function
```

ViewModel はこの ID を使用して新しいノートの詳細ページにリダイレクト:

```xojo
// NotesCreateVM.OnPost() で
Var newID As Integer = NoteModel.Create(title, body)
SetFlash("Note created.", "success")
Redirect("/notes/" + Str(newID))
```

## カラム型

SQLite は動的に型付けされています。Xojo の `RowSet` カラムアクセサーは読み取り時に値を変換します:

| アクセサー | 使用用途 |
|---|---|
| `.StringValue` | `TEXT` カラム、ID (安全なデフォルト) |
| `.IntegerValue` | `INTEGER` カラム |
| `.DoubleValue` | `REAL` カラム |
| `.BooleanValue` | `INTEGER` 0/1 ブール値として保存 |

SQLite の `datetime()` 関数を使用してすべての日付を `TEXT` として保存します。文字列として取得し表示します — 必要に応じてテンプレートまたは ViewModel で形式化します。

## 本番用のデータベースパス

現在の実装は開発用にパスをハードコードしています。本番ビルドの場合、`SpecialFolder.ApplicationData` を使用:

```xojo
// 開発 (ハードコード — IDE デバッグ実行に適しています)
Const DB_PATH = "/Users/worajedt/Xojo Projects/mvvm/data/notes.sqlite"

// 本番 (正しいアプローチ)
Function ProductionDBPath() As String
  Var appData As FolderItem = SpecialFolder.ApplicationData
  Var appDir As FolderItem = appData.Child("mvvm")
  If Not appDir.Exists Then appDir.CreateDirectory()
  Return appDir.Child("notes.sqlite").NativePath
End Function
```

ビルド定数またはプリファレンスを使用して開発と本番パス間を切り替えます。

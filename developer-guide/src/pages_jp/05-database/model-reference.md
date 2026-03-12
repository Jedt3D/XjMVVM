---
title: "データベースレイヤーリファレンス"
description: "3層のDBAdapter / BaseModel / NoteModelアーキテクチャ — 設計原理、接続ライフサイクル、完全なCRUD API、および新しいリソースの追加方法。"
---

# データベースレイヤーリファレンス

## 3層アーキテクチャ

データベースレイヤーは3つの異なる責務を分離します。各層は、その下の層だけを認識します。

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: right
#spacing: 48
#padding: 10
#lineWidth: 1.5
[DBAdapter: Module|connection factory\nschema init] -> [BaseModel: Class|generic CRUD\nFindAll / FindByID\nInsert / UpdateByID\nDeleteByID]
[BaseModel: Class|generic CRUD\nFindAll / FindByID\nInsert / UpdateByID\nDeleteByID] -> [NoteModel: Class|TableName()\nColumns()\nthin wrappers]
[NoteModel: Class|TableName()\nColumns()\nthin wrappers] -> [<database> SQLite]
-->
<!-- ascii
DBAdapter (Module)
  └─ connection factory, schema init
      │
      ▼
BaseModel (Class)
  └─ generic CRUD: FindAll, FindByID, Insert, UpdateByID, DeleteByID
      │
      ▼
NoteModel (Class)
  └─ TableName(), Columns(), thin wrappers, escape hatch for timestamps
      │
      ▼
SQLite database file
-->
<!-- /diagram -->

この分離により以下が実現します:

- **リソースモデルにボイラープレートなし** — `NoteModel`は約20行です。テーブルと列を宣言し、汎用操作を`BaseModel`に委譲し、カスタムSQLが必要な場合のみ記述します。
- **接続ロジックの変更が一箇所** — SQLiteからPostgreSQLへの移行は`DBAdapter.Connect()`のみに影響します。
- **明確なエスケープハッチ** — `BaseModel.OpenDB()`はサブクラスに生DB アクセスを提供し、汎用層を破壊しません。

---

## 設計決定

### なぜ`Dictionary`をモデルインスタンスの代わりに返すのか?

JinjaXテンプレートはドット記法を使用します: `{{ note.title }}`。JinjaXエンジンはXojoの`Dictionary`に対して`dict.Value("title")`を呼び出すことでこれを解決します。カスタムクラスインスタンスには同等のイントロスペクション機構がありません。

```xojo
// テンプレート: {{ note.title }}

// ✅ 動作 — Dictionaryはドット記法を満たす
ctx.Value("note") = myDictionary        // .Value("title") → "Hello"

// ❌ 動作しない — NoteModelはJinjaXイントロスペクションを持たない
ctx.Value("note") = myNoteInstance
```

!!! warning
    すべてのモデルメソッドは`Dictionary`または`Variant()`の`Dictionary`を返す必要があります。これはデータレイヤーにおける最も重要なアーキテクチャルルールです。カスタムクラスインスタンスはJinjaXテンプレートで使用できません。

### なぜリクエストごとに1つの接続なのか?

Xojo Webは別々のスレッドで同時HTTPリクエストを処理します。スレッド間で共有される`SQLiteDatabase`はロッキングが必要であり、デッドロックのリスクがあります。

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: right
#spacing: 40
#padding: 8
#lineWidth: 1.5
[Thread A: GET /notes|DBAdapter.Connect()\nSELECT *\ndb.Close()] -- no conflict -- [Thread B: POST /notes|DBAdapter.Connect()\nINSERT INTO notes\ndb.Close()]
-->
<!-- ascii
スレッド A (GET /notes)      スレッド B (POST /notes)
  DBAdapter.Connect()          DBAdapter.Connect()
  SELECT * FROM notes          INSERT INTO notes ...
  db.Close()                   db.Close()
       ↑ 独立、競合なし ↑
-->
<!-- /diagram -->

リクエストごとに新しい接続を開くのは安全です。ローカルファイル接続を開く際のSQLiteのオーバーヘッドは、典型的な内部ツールトラフィックボリュームでは無視できます。

---

## 接続ライフサイクル

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: down
#spacing: 30
#padding: 8
#lineWidth: 1.5
[App.Opening|resolve paths\nExecutableFile.Parent] InitDB() -> [DBAdapter.Connect()]
[DBAdapter.Connect()] CREATE TABLE IF NOT EXISTS -> [db.Close()]
[db.Close()] app ready -> [Per-request]
[Per-request] -> [DBAdapter.Connect(): open]
[DBAdapter.Connect(): open] -> [SQL: SELECT / INSERT / UPDATE / DELETE]
[SQL: SELECT / INSERT / UPDATE / DELETE] -> [RowSet → RowToDict()]
[RowSet → RowToDict()] -> [db.Close(): close]
[db.Close(): close] Dictionary -> [ViewModel]
-->
<!-- ascii
App.Opening (1回)
  ├── パスを解決: ExecutableFile.Parent / "data" および / "templates"
  ├── DBAdapter.InitDB()
  │     └── Connect() → CREATE TABLE IF NOT EXISTS ... → db.Close()
  └── JinjaEnvironment(FileSystemLoader(tplDir))

リクエストごと (同時実行、独立)
  HandleURL → Router → ViewModel → Model method
    └── DBAdapter.Connect()       ← 開く
    └── SELECT / INSERT / ...     ← 実行
    └── RowSet → RowToDict()      ← Dictionaryにマップ
    └── db.Close()                ← 閉じる
    └── Dictionaryを返す          ← ViewModel → JinjaX → HTML
-->
<!-- /diagram -->

!!! warning
    `Connect()`を呼び出すすべてのコードパスは、リターン前に`db.Close()`を呼び出す必要があります — エラーパスを含みます。すべての`BaseModel`メソッドはすべてのリターン分岐で接続を閉じます。

---

## DBAdapter (モジュール)

**ファイル:** `Framework/DBAdapter.xojo_code`

モジュール — インスタンス化は不要 — で、接続ファクトリとスキーマセットアップを所有しています。

### `Connect() As SQLiteDatabase`

新しい接続を開いて返します。呼び出し元が`db.Close()`を実行する責務があります。

データベースファイルは、実行可能ファイルの**隣の** `data/`フォルダに配置されます — `App.ExecutableFile.Parent`経由で解決されます。Xojoデバッガと構築された本番バイナリで同じように動作します。`data/`ディレクトリが存在しない場合は自動作成されます。

```xojo
Function Connect() As SQLiteDatabase
  // 実行可能ファイルの隣にdata/を解決 (デバッグと本番両方で動作)
  Var dataDir As FolderItem = App.ExecutableFile.Parent.Child("data")
  If Not dataDir.Exists Then dataDir.CreateAsFolder()

  Var db As New SQLiteDatabase
  db.DatabaseFile = dataDir.Child("notes.sqlite")
  db.Connect()
  Return db
End Function
```

!!! note
    `App.ExecutableFile`は実行中のバイナリです — Xojoデバッガではこれはデバッグスタブで、本番ではコンパイルされたアプリです。どちらの場合も`Parent`を同じフォルダに解決するため、パスは環境全体で安定しています。

### `InitDB()`

テーブルが存在しない場合は作成します。`App.Opening`から1回呼ばれます。すべてのスタートアップで呼び出しても安全です — `CREATE TABLE IF NOT EXISTS`はべき等です。

新しいテーブルを追加するには、`db.Close()`前にここに別の`ExecuteSQL`を追加します。

### App.Opening — スタートアップパス

`App.Opening`は、リクエストが提供される前にランタイムパスをワイヤアップする単一の場所です:

```xojo
Sub Opening()
  // テンプレート — 実行可能ファイルに相対、DBと同じ
  Var tplDir As FolderItem = App.ExecutableFile.Parent.Child("templates")
  mJinja = New JinjaEnvironment(New JinjaX.FileSystemLoader(tplDir.NativePath))

  // データベース — 最初の起動時にスキーマを作成
  DBAdapter.InitDB()

  // ルータ — すべてのルートを登録
  mRouter = New Router()
  RegisterRoutes()
End Sub
```

`templates/`と`data/`の両方は実行可能ファイルと同じ場所にあります。つまり、バイナリとそれら2つのフォルダを一緒にコピーすることでアプリをデプロイできます — 絶対パスや環境変数は不要です。

---

## BaseModel (クラス)

**ファイル:** `Framework/BaseModel.xojo_code`

汎用CRUDベースクラス。サブクラスは2つのメソッドをオーバーライドし、すべての操作を継承します。

### サブクラスコントラクト

| メソッド | 必須 | 返り値 | 目的 |
|--------|------|--------|------|
| `TableName() As String` | はい | `"notes"` | SQLテーブル名 |
| `Columns() As String` | はい | `"id, title, body, ..."` | `SELECT`用のカンマ区切り列リスト |

### CRUDメソッド

#### `FindAll(orderBy As String = "") As Variant()`

すべての行を`orderBy`で順序付けて返します。各要素は`Dictionary`です。

```xojo
Var rows() As Variant = model.FindAll("updated_at DESC")
// rows(0) → Dictionary: {"id": "1", "title": "Hello", ...}
```

#### `FindByID(id As Integer) As Dictionary`

一致する行を返すか、見つからない場合は`Nil`を返します。常に使用前にチェックします:

```xojo
Var row As Dictionary = model.FindByID(42)
If row Is Nil Then
  RenderError(404, "Not found")
  Return
End If
```

#### `Insert(data As Dictionary) As Integer`

Dictionaryキーからパラメータ化された`INSERT`を構築します。新しい`ROWID`を返します。SQLインジェクション安全 — `SQLitePreparedStatement`を使用します。

```xojo
Var data As New Dictionary
data.Value("title") = "My Note"
data.Value("body")  = "Content"
Var newID As Integer = model.Insert(data)
```

!!! note
    `Insert`はSQLite側式(`datetime('now')`)を表現できません — エスケープハッチを通す必要があります。下記のNoteModelを参照します。

#### `UpdateByID(id As Integer, data As Dictionary)`

パラメータ化された`UPDATE ... WHERE id = ?`。Dictionaryに存在するキーのみが更新されます。

```xojo
Var data As New Dictionary
data.Value("title") = "New Title"
model.UpdateByID(42, data)
```

#### `DeleteByID(id As Integer)`

```xojo
model.DeleteByID(42)
```

### 保護されたエスケープハッチメソッド

#### `OpenDB() As SQLiteDatabase`

カスタムSQLが必要なサブクラス用の生接続を返します。サブクラスが`db.Close()`を実行する責務があります。

使用時機:
- SQLite式(`datetime('now')`, `strftime(...)`)がSQLで必要 — `?`パラメータにはできない
- `JOIN`, `GROUP BY`, `HAVING`またはサブクエリを含む複雑なクエリ
- `INSERT`後の`db.LastRowID`が必要
- 複数のステートメントが1つの接続を共有する必要がある

#### `RowToDict(rs As RowSet) As Dictionary`

現在のRowSet行を`Columns()`の列名を使用して`Dictionary`にマップします。すべての値は`StringValue`として保存されます — 意図的です。JinjaXはすべてをテキストとしてレンダリングします。ViewModelsは必要に応じて`Val()`経由で整数にキャストします。

---

## NoteModel (クラス)

**ファイル:** `Models/NoteModel.xojo_code`

具体的なリソースモデル。すべてのメソッドはユーザーごとにノートをスコープするために`userID`パラメータが必要です — 各ユーザーは自分のノートのみを表示および変更できます。

```xojo
Protected Class NoteModel
Inherits BaseModel

  Protected Function TableName() As String
    Return "notes"
  End Function

  Protected Function Columns() As String
    Return "id, title, body, created_at, updated_at, user_id"
  End Function

  // すべてのメソッドはユーザーごとスコープのためにuserIDが必須
  Function GetAll(userID As Integer) As Variant()
    Var results() As Variant
    Var db As SQLiteDatabase = OpenDB()
    Var rs As RowSet = db.SelectSQL( _
      "SELECT " + Columns() + " FROM notes WHERE user_id = ? ORDER BY updated_at DESC", userID)
    While Not rs.AfterLastRow
      results.Add(RowToDict(rs))
      rs.MoveToNextRow()
    Wend
    rs.Close()
    db.Close()
    Return results
  End Function

  Function GetByID(id As Integer, userID As Integer) As Dictionary
    Var db As SQLiteDatabase = OpenDB()
    Var rs As RowSet = db.SelectSQL( _
      "SELECT " + Columns() + " FROM notes WHERE id = ? AND user_id = ?", id, userID)
    If rs.AfterLastRow Then
      rs.Close()
      db.Close()
      Return Nil
    End If
    Var row As Dictionary = RowToDict(rs)
    rs.Close()
    db.Close()
    Return row
  End Function

  Function Create(title As String, body As String, userID As Integer) As Integer
    Var db As SQLiteDatabase = OpenDB()
    db.ExecuteSQL("INSERT INTO notes (title, body, user_id) VALUES (?, ?, ?)", title, body, userID)
    Var newID As Integer = db.LastRowID
    db.Close()
    Return newID
  End Function

  Sub Update(id As Integer, title As String, body As String, userID As Integer)
    Var db As SQLiteDatabase = OpenDB()
    db.ExecuteSQL( _
      "UPDATE notes SET title = ?, body = ?, updated_at = datetime('now') " + _
      "WHERE id = ? AND user_id = ?", title, body, id, userID)
    db.Close()
  End Sub

  Sub Delete(id As Integer, userID As Integer)
    Var db As SQLiteDatabase = OpenDB()
    db.ExecuteSQL("DELETE FROM notes WHERE id = ? AND user_id = ?", id, userID)
    db.Close()
  End Sub

  Function CountForUser(userID As Integer) As Integer
    Var db As SQLiteDatabase = OpenDB()
    Var rs As RowSet = db.SelectSQL( _
      "SELECT COUNT(*) AS cnt FROM notes WHERE user_id = ?", userID)
    Var count As Integer = rs.Column("cnt").IntegerValue
    rs.Close()
    db.Close()
    Return count
  End Function

End Class
```

`Create`と`Update`はエスケープハッチを使用します。`datetime('now')`はSQLiteで評価される式であるため — 文字列`"datetime('now')"`を`?`パラメータとしてバインドすると、タイムスタンプではなくリテラルテキストが保存されます。

すべてのクエリはSQL レベルで所有権を強制するために`WHERE user_id = ?`を含みます。完全なパターンについては[保護されたルート & ユーザースコープ](../protected-routes/index.html)を参照してください。

---

## CRUDタスクマッピング

すべてのNotesルートは認証が必要です。すべてのモデル呼び出しはデータをユーザーごとにスコープするために`userID`を含みます。

| ユーザーアクション | HTTP | ViewModel | モデル呼び出し | SQL |
|-------------|------|-----------|------------|-----|
| リスト表示 | `GET /notes` | `NotesListVM` | `NoteModel.GetAll(userID)` | `SELECT … WHERE user_id = ? ORDER BY updated_at DESC` |
| 1件表示 | `GET /notes/:id` | `NotesDetailVM` | `NoteModel.GetByID(id, userID)` | `SELECT … WHERE id = ? AND user_id = ?` |
| 新規フォーム | `GET /notes/new` | `NotesNewVM` | — | — |
| 作成 | `POST /notes` | `NotesCreateVM` | `NoteModel.Create(title, body, userID)` | `INSERT INTO notes (title, body, user_id) VALUES (?, ?, ?)` |
| 編集フォーム | `GET /notes/:id/edit` | `NotesEditVM` | `NoteModel.GetByID(id, userID)` | `SELECT … WHERE id = ? AND user_id = ?` |
| 更新 | `POST /notes/:id` | `NotesUpdateVM` | `NoteModel.Update(id, title, body, userID)` | `UPDATE notes SET … WHERE id = ? AND user_id = ?` |
| 削除 | `POST /notes/:id/delete` | `NotesDeleteVM` | `NoteModel.Delete(id, userID)` | `DELETE FROM notes WHERE id = ? AND user_id = ?` |

---

## メリットとトレードオフ

| メリット | 理由 |
|---------|-----|
| ボイラープレートなし | 新しいリソースには`TableName()` + `Columns()` + シンプルなラッパーのみが必要 |
| SQLインジェクション安全 | すべてのユーザー値は`?`パラメータバインディングを通す |
| スレッドセーフ | リクエストごとの接続 — 共有可変状態なし |
| JinjaX互換 | すべての結果は`Dictionary` — テンプレートはすぐに動作 |
| テスト可能 | XojoUnitテストは本当のSQLite DBにヒット; オーバーヘッドは無視可能 |
| 明確なエスケープハッチ | `OpenDB()`は文書化され意図的で、ワークアラウンドではない |

| トレードオフ | 影響 |
|-----------|--------|
| ORMフィーチャなし | アソシエーション、遅延ロード、またはチェンジトラッキングなし |
| 文字列のみの値 | `RowToDict`はすべてを`StringValue`として保存; ViewModelsは`Val()`経由でキャスト必須 |
| マイグレーションシステムなし | スキーマ変更は手動`ALTER TABLE`またはdevでのDB再作成が必須 |
| `datetime`制限 | `BaseModel.Insert`は`DEFAULT (datetime('now'))`を使用できません — エスケープハッチを使用 |

### 継承されたCRUD対エスケープハッチ使用時

操作が単純な`SELECT`, `INSERT`, `UPDATE`, または`DELETE`でプレーンなバインド値のみ場合は`BaseModel`継承メソッドを使用します。

SQLite式(`datetime('now')`, `strftime(...)`)が必要、複雑なクエリ(`JOIN`, `GROUP BY`, サブクエリ)、カスタムinsert後の`db.LastRowID`、または1つの接続で複数のステートメントを共有する必要がある場合は`OpenDB()`を使用します。

---

## 新しいリソース追加

完全な例として`TagModel`を追加:

**1. `Models/TagModel.xojo_code`を作成:**

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

  Sub Delete(id As Integer)
    DeleteByID(id)
  End Sub

End Class
```

**2. `DBAdapter.InitDB()`にテーブルを追加:**

```xojo
db.ExecuteSQL( _
  "CREATE TABLE IF NOT EXISTS tags (" + _
  "id         INTEGER PRIMARY KEY AUTOINCREMENT, " + _
  "name       TEXT NOT NULL, " + _
  "created_at TEXT DEFAULT (datetime('now')))")
```

**3. 登録** `Models/TagModel.xojo_code`を`mvvm.xojo_project`のModelsフォルダに登録します (Xojo IDE: ファイルをプロジェクトパネルにドラッグ)。

**4. ViewModelsを作成** `ViewModels/Tags/`に、**テンプレート**を`templates/tags/`に、`Notes`と同じパターンに従って作成します。
---
title: データベースレイヤーリファレンス
description: 3層DBAdapter / BaseModel / NoteModelアーキテクチャ — 設計根拠、接続ライフサイクル、完全なCRUD API、および新しいリソースを追加する方法。
---

# データベースレイヤーリファレンス

## 3層アーキテクチャ

データベースレイヤーは、3つの異なる責任を分離します。各層は、それより下の層についてのみ知っています。

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

この分離は以下を意味します：

- **リソースモデルのボイラープレートなし** — `NoteModel`は約20行です。テーブルと列を宣言し、一般的な操作を`BaseModel`に委譲し、カスタムSQLが必要な場合のみ記述します。
- **接続ロジックを変更する単一の場所** — SQLiteからPostgreSQLへの移動は、`DBAdapter.Connect()`のみを触れます。
- **クリアなエスケープハッチ** — `BaseModel.OpenDB()`はサブクラスに一般的なレイヤーを破壊することなく生のDB アクセスを与えます。

---

## 設計上の決定

### モデルインスタンスの代わりに`Dictionary`を返すのはなぜか？

JinjaXテンプレートはドット記法を使用します：`{{ note.title }}`。JinjaXエンジンは、Xojo`Dictionary`に対して`dict.Value("title")`を呼び出すことでこれを解決します。カスタムクラスインスタンスは、同等のイントロスペクションメカニズムを持ちません。

```xojo
// Template: {{ note.title }}

// ✅ Works — Dictionary satisfies dot-notation
ctx.Value("note") = myDictionary        // .Value("title") → "Hello"

// ❌ Does NOT work — NoteModel has no JinjaX introspection
ctx.Value("note") = myNoteInstance
```

!!! warning
    すべてのモデルメソッドは`Dictionary`または`Variant()`の`Dictionary`を返す必要があります。これはデータレイヤーで最も重要なアーキテクチャルールです。カスタムクラスインスタンスはJinjaXテンプレートで使用することはできません。

### 1つのリクエストあたり1つの接続はなぜか？

Xojo Webは、並行HTTPリクエストを別々のスレッドで処理します。スレッド全体で共有される`SQLiteDatabase`にはロッキングが必要で、デッドロックのリスクがあります。

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
Thread A (GET /notes)         Thread B (POST /notes)
  DBAdapter.Connect()           DBAdapter.Connect()
  SELECT * FROM notes           INSERT INTO notes ...
  db.Close()                    db.Close()
       ↑ independent, no conflict ↑
-->
<!-- /diagram -->

各呼び出しごとに新しい接続を開くことは安全です。SQLiteのローカルファイル接続を開くことのオーバーヘッドは、通常的な内部ツールのトラフィック量では無視できます。

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
App.Opening (once)
  ├── Resolve paths: ExecutableFile.Parent / "data" and / "templates"
  ├── DBAdapter.InitDB()
  │     └── Connect() → CREATE TABLE IF NOT EXISTS ... → db.Close()
  └── JinjaEnvironment(FileSystemLoader(tplDir))

Per-request (concurrent, independent)
  HandleURL → Router → ViewModel → Model method
    └── DBAdapter.Connect()       ← open
    └── SELECT / INSERT / ...     ← execute
    └── RowSet → RowToDict()      ← map to Dictionary
    └── db.Close()                ← close
    └── Return Dictionary         ← to ViewModel → JinjaX → HTML
-->
<!-- /diagram -->

!!! warning
    `Connect()`を呼び出すすべてのコードパスは、エラーパスを含む、戻る前に`db.Close()`を呼び出す必要があります。すべての`BaseModel`メソッドはすべての戻りブランチで接続を閉じます。

---

## DBAdapter （Module）

**File:** `Framework/DBAdapter.xojo_code`

モジュール — インスタンス化は必要ありません — 接続ファクトリとスキーマセットアップを所有しています。

### `Connect() As SQLiteDatabase`

新しい接続を開いて返します。呼び出し側は`db.Close()`の責任があります。

データベースファイルは、実行可能ファイルの**隣の** `data/`フォルダに存在します — `App.ExecutableFile.Parent`を経由で解決されます。これはXojoデバッガーと構築された本番バイナリの両方で同じように機能します。`data/`ディレクトリが存在しない場合は自動的に作成されます。

```xojo
Function Connect() As SQLiteDatabase
  // Resolve data/ next to the executable (works in debug and production)
  Var dataDir As FolderItem = App.ExecutableFile.Parent.Child("data")
  If Not dataDir.Exists Then dataDir.CreateAsFolder()

  Var db As New SQLiteDatabase
  db.DatabaseFile = dataDir.Child("notes.sqlite")
  db.Connect()
  Return db
End Function
```

!!! note
    `App.ExecutableFile`は実行中のバイナリです — Xojoデバッガーではこれはデバッグスタブで、本番ではコンパイルされたアプリケーションです。両方のケースで`Parent`を同じフォルダに解決するため、パスは環境全体で安定しています。

### `InitDB()`

存在しない場合はすべてのテーブルを作成します。`App.Opening`から一度呼び出されます。すべての起動で呼び出すのは安全です — `CREATE TABLE IF NOT EXISTS`は冪等です。

新しいテーブルを追加するには、`db.Close()`の前にここに別の`ExecuteSQL`を追加してください。

### App.Opening — スタートアップパス

`App.Opening`は、任意のリクエストが提供される前に両方のランタイムパスをワイヤーアップする単一の場所です：

```xojo
Sub Opening()
  // Templates — resolved relative to executable, same as DB
  Var tplDir As FolderItem = App.ExecutableFile.Parent.Child("templates")
  mJinja = New JinjaEnvironment(New JinjaX.FileSystemLoader(tplDir.NativePath))

  // Database — create schema on first launch
  DBAdapter.InitDB()

  // Router — register all routes
  mRouter = New Router()
  RegisterRoutes()
End Sub
```

`templates/`と`data/`の両方は実行可能ファイルの隣に位置します。これは、バイナリをこれら2つのフォルダと一緒にコピーすることでアプリをデプロイできることを意味します — 絶対パスも環境変数も必要ありません。

---

## BaseModel （Class）

**File:** `Framework/BaseModel.xojo_code`

一般的なCRUD基本クラス。サブクラスは2つのメソッドをオーバーライドし、すべての操作を継承します。

### サブクラス契約

| Method | Required | Returns | Purpose |
|--------|----------|---------|---------|
| `TableName() As String` | Yes | `"notes"` | SQLテーブル名 |
| `Columns() As String` | Yes | `"id, title, body, ..."` | `SELECT`のカンマ区切り列リスト |

### CRUDメソッド

#### `FindAll(orderBy As String = "") As Variant()`

`orderBy`でソートされたすべての行を返します。各要素は`Dictionary`です。

```xojo
Var rows() As Variant = model.FindAll("updated_at DESC")
// rows(0) → Dictionary: {"id": "1", "title": "Hello", ...}
```

#### `FindByID(id As Integer) As Dictionary`

マッチする行を返すか、見つからない場合は`Nil`を返します。使用する前に常にチェックしてください：

```xojo
Var row As Dictionary = model.FindByID(42)
If row Is Nil Then
  RenderError(404, "Not found")
  Return
End If
```

#### `Insert(data As Dictionary) As Integer`

ディクショナリキーから`INSERT`をパラメータ化します。新しい`ROWID`を返します。SQL注入セーフです — `SQLitePreparedStatement`を使用します。

```xojo
Var data As New Dictionary
data.Value("title") = "My Note"
data.Value("body")  = "Content"
Var newID As Integer = model.Insert(data)
```

!!! note
    `Insert`は`datetime('now')`のようなSQLite側の式を表現することはできません — これらはエスケープハッチを通じて行く必要があります。下記のNoteModelを参照してください。

#### `UpdateByID(id As Integer, data As Dictionary)`

パラメータ化`UPDATE ... WHERE id = ?`。ディクショナリに存在するキーのみが更新されます。

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

サブクラスがカスタムSQLを必要とするために生の接続を返します。サブクラスは`db.Close()`の責任があります。

以下の場合に使用してください：
- SQLite式（`datetime('now')`、`strftime(...)`）がSQLで必要です — `?`パラメータにはできません
- 複雑なクエリ（`JOIN`、`GROUP BY`、`HAVING`、またはサブクエリ）
- `INSERT`後に`db.LastRowID`が必要です
- 複数のステートメントが1つの接続を共有する必要があります

#### `RowToDict(rs As RowSet) As Dictionary`

現在のRowSetの行を、`Columns()`の列名を使用して`Dictionary`にマップします。すべての値は`StringValue`として格納されます — 意図的です。JinjaXはすべてを文字列としてレンダリングします。ViewModelは必要に応じて`Val()`を使用して整数にキャストします。

---

## NoteModel （Class）

**File:** `Models/NoteModel.xojo_code`

具体的なリソースモデル。`BaseModel`がすべての一般的なことを処理するため、約20行のみです。

```xojo
Protected Class NoteModel
Inherits BaseModel

  Protected Function TableName() As String
    Return "notes"
  End Function

  Protected Function Columns() As String
    Return "id, title, body, created_at, updated_at"
  End Function

  // Delegation — zero boilerplate
  Function GetAll() As Variant()
    Return FindAll("updated_at DESC")
  End Function

  Function GetByID(id As Integer) As Dictionary
    Return FindByID(id)
  End Function

  Sub Delete(id As Integer)
    DeleteByID(id)
  End Sub

  // Escape hatch — SQLite expressions required for timestamps
  Function Create(title As String, body As String) As Integer
    Var db As SQLiteDatabase = OpenDB()
    db.ExecuteSQL("INSERT INTO notes (title, body) VALUES (?, ?)", title, body)
    Var newID As Integer = db.LastRowID
    db.Close()
    Return newID
  End Function

  Sub Update(id As Integer, title As String, body As String)
    Var db As SQLiteDatabase = OpenDB()
    db.ExecuteSQL( _
      "UPDATE notes SET title = ?, body = ?, updated_at = datetime('now') WHERE id = ?", _
      title, body, id)
    db.Close()
  End Sub

End Class
```

`Create`と`Update`はエスケープハッチを使用します。なぜなら`datetime('now')`はSQLite評価式だからです — 文字列`"datetime('now')"`を`?`パラメータとしてバインドすることはタイムスタンプではなくリテラルテキストを格納します。

---

## CRUD タスクマッピング

| User action | HTTP | ViewModel | Model call | SQL |
|-------------|------|-----------|------------|-----|
| リストを表示 | `GET /notes` | `NotesListVM` | `NoteModel.GetAll()` | `SELECT … ORDER BY updated_at DESC` |
| 1つを表示 | `GET /notes/:id` | `NotesDetailVM` | `NoteModel.GetByID(id)` | `SELECT … WHERE id = ?` |
| 新しいフォーム | `GET /notes/new` | `NotesNewVM` | — | — |
| 作成 | `POST /notes` | `NotesCreateVM` | `NoteModel.Create(title, body)` | `INSERT INTO notes (title, body) VALUES (?, ?)` |
| フォームを編集 | `GET /notes/:id/edit` | `NotesEditVM` | `NoteModel.GetByID(id)` | `SELECT … WHERE id = ?` |
| 更新 | `POST /notes/:id` | `NotesUpdateVM` | `NoteModel.Update(id, title, body)` | `UPDATE notes SET … WHERE id = ?` |
| 削除 | `POST /notes/:id/delete` | `NotesDeleteVM` | `NoteModel.Delete(id)` | `DELETE FROM notes WHERE id = ?` |

---

## 利益とトレードオフ

| Benefit | Why |
|---------|-----|
| ボイラープレートなし | 新しいリソースには`TableName()` + `Columns()` + シンラッパーのみが必要です |
| SQL注入セーフ | すべてのユーザー値は`?`パラメータバインディングを通過します |
| スレッドセーフ | リクエストあたりの接続 — 共有可変状態なし |
| JinjaX互換 | すべての結果は`Dictionary`です — テンプレートはすぐに機能します |
| テスト可能 | XojoUnitテストは本当のSQLite DBをヒットします。無視できるオーバーヘッド |
| クリアなエスケープハッチ | `OpenDB()`は文書化されており意図的で、回避策ではなく |

| Trade-off | Impact |
|-----------|--------|
| ORM機能なし | 関連付け、遅延ロード、または変更追跡なし |
| 文字列のみの値 | `RowToDict`はすべてを`StringValue`として格納します。ViewModelは必要に応じて`Val()`を使用してキャストする必要があります |
| 移行システムなし | スキーマの変更には手動`ALTER TABLE`またはdevで DBを再作成する必要があります |
| `datetime`制限 | `BaseModel.Insert`は`DEFAULT (datetime('now'))`を使用できません — エスケープハッチを使用してください |

### 継承されたCRUDとエスケープハッチをいつ使用するか

プレーン値がバインドされた単純`SELECT`、`INSERT`、`UPDATE`、または`DELETE`の場合は、`BaseModel`継承メソッドを使用してください。

SQLite式（`datetime('now')`、`strftime(...)`）、複雑なクエリ（`JOIN`、`GROUP BY`、サブクエリ）、カスタム挿入後の`db.LastRowID`、または1つの接続内の複数のステートメントが必要な場合は`OpenDB()`を使用してください。

---

## 新しいリソースを追加

`TagModel`を完全な例として追加：

**1. `Models/TagModel.xojo_code`を作成：**

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

**2. `DBAdapter.InitDB()`にテーブルを追加：**

```xojo
db.ExecuteSQL( _
  "CREATE TABLE IF NOT EXISTS tags (" + _
  "id         INTEGER PRIMARY KEY AUTOINCREMENT, " + _
  "name       TEXT NOT NULL, " + _
  "created_at TEXT DEFAULT (datetime('now')))")
```

**3. Register** `Models/TagModel.xojo_code` in `mvvm.xojo_project` under the Models folder (Xojo IDE: drag the file into the project panel).

**4. ViewModels** in `ViewModels/Tags/` と **templates** in `templates/tags/` を`Notes`と同じパターンに従って作成してください。

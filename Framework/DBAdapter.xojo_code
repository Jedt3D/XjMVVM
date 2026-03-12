#tag Module
Protected Module DBAdapter
	#tag Method, Flags = &h0, Description = "Returns a fresh SQLiteDatabase connection. Call Close() when done."
		Function Connect() As SQLiteDatabase
		  Var dataFolder As FolderItem = App.ExecutableFile.Parent.Child("data")
		  If Not dataFolder.Exists Then dataFolder.CreateFolder()
		  Var dbFile As FolderItem = dataFolder.Child("notes.sqlite")
		  Var db As New SQLiteDatabase
		  db.DatabaseFile = dbFile
		  db.Connect()
		  Return db
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Creates the database and schema on first run. Call once from App.Opening."
		Sub InitDB()
		  Var db As SQLiteDatabase = Connect()
		  db.ExecuteSQL("CREATE TABLE IF NOT EXISTS notes (" + _
		  "id INTEGER PRIMARY KEY AUTOINCREMENT, " + _
		  "title TEXT NOT NULL, " + _
		  "body TEXT, " + _
		  "created_at TEXT DEFAULT (datetime('now')), " + _
		  "updated_at TEXT DEFAULT (datetime('now')))")
		  db.ExecuteSQL("CREATE TABLE IF NOT EXISTS tags (" + _
		  "id INTEGER PRIMARY KEY AUTOINCREMENT, " + _
		  "name TEXT NOT NULL, " + _
		  "created_at TEXT DEFAULT (datetime('now')))")
		  db.Close()
		End Sub
	#tag EndMethod

End Module
#tag EndModule

#tag Class
Protected Class NoteModel
	#tag Method, Flags = &h0, Description = "Opens (or creates) the SQLite database and ensures the notes table exists."
		Shared Function InitDB() As SQLiteDatabase
		  Var dbFile As New FolderItem("/Users/worajedt/Xojo Projects/mvvm/data/notes.sqlite", FolderItem.PathModes.Native)
		  Var db As New SQLiteDatabase
		  db.DatabaseFile = dbFile

		  If Not dbFile.Exists Then
		    db.CreateDatabase()
		  Else
		    db.Connect()
		  End If

		  db.ExecuteSQL("CREATE TABLE IF NOT EXISTS notes (" + _
		  "id INTEGER PRIMARY KEY AUTOINCREMENT, " + _
		  "title TEXT NOT NULL, " + _
		  "body TEXT, " + _
		  "created_at TEXT DEFAULT (datetime('now')), " + _
		  "updated_at TEXT DEFAULT (datetime('now')))")

		  Return db
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21, Description = "Opens a fresh DB connection for thread-safe access."
		Private Function OpenDB() As SQLiteDatabase
		  Var dbFile As New FolderItem("/Users/worajedt/Xojo Projects/mvvm/data/notes.sqlite", FolderItem.PathModes.Native)
		  Var db As New SQLiteDatabase
		  db.DatabaseFile = dbFile
		  db.Connect()
		  Return db
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Returns all notes as a Variant() of Dictionary objects."
		Function GetAll() As Variant()
		  Var results() As Variant
		  Var db As SQLiteDatabase = OpenDB()
		  Var rs As RowSet = db.SelectSQL("SELECT id, title, body, created_at, updated_at FROM notes ORDER BY updated_at DESC")

		  While Not rs.AfterLastRow
		    Var row As New Dictionary()
		    row.Value("id") = rs.Column("id").IntegerValue
		    row.Value("title") = rs.Column("title").StringValue
		    row.Value("body") = rs.Column("body").StringValue
		    row.Value("created_at") = rs.Column("created_at").StringValue
		    row.Value("updated_at") = rs.Column("updated_at").StringValue
		    results.Add(row)
		    rs.MoveToNextRow()
		  Wend

		  rs.Close()
		  db.Close()
		  Return results
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Returns a single note as a Dictionary, or Nil if not found."
		Function GetByID(id As Integer) As Dictionary
		  Var db As SQLiteDatabase = OpenDB()
		  Var rs As RowSet = db.SelectSQL("SELECT id, title, body, created_at, updated_at FROM notes WHERE id = ?", id)

		  If rs.AfterLastRow Then
		    rs.Close()
		    db.Close()
		    Return Nil
		  End If

		  Var row As New Dictionary()
		  row.Value("id") = rs.Column("id").IntegerValue
		  row.Value("title") = rs.Column("title").StringValue
		  row.Value("body") = rs.Column("body").StringValue
		  row.Value("created_at") = rs.Column("created_at").StringValue
		  row.Value("updated_at") = rs.Column("updated_at").StringValue

		  rs.Close()
		  db.Close()
		  Return row
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Creates a new note and returns its ID."
		Function Create(title As String, body As String) As Integer
		  Var db As SQLiteDatabase = OpenDB()
		  db.ExecuteSQL("INSERT INTO notes (title, body) VALUES (?, ?)", title, body)
		  Var newID As Integer = db.LastRowID
		  db.Close()
		  Return newID
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Updates an existing note."
		Sub Update(id As Integer, title As String, body As String)
		  Var db As SQLiteDatabase = OpenDB()
		  db.ExecuteSQL("UPDATE notes SET title = ?, body = ?, updated_at = datetime('now') WHERE id = ?", title, body, id)
		  db.Close()
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Deletes a note by ID."
		Sub Delete(id As Integer)
		  Var db As SQLiteDatabase = OpenDB()
		  db.ExecuteSQL("DELETE FROM notes WHERE id = ?", id)
		  db.Close()
		End Sub
	#tag EndMethod


	#tag ViewBehavior
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			InitialValue=""
			Type="String"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			InitialValue="-2147483648"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			InitialValue=""
			Type="String"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Left"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Top"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass

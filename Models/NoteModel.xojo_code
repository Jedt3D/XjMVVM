#tag Class
Protected Class NoteModel
Inherits BaseModel
	#tag Method, Flags = &h1, Description = "Returns the table name."
		Protected Function TableName() As String
		  Return "notes"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1, Description = "Returns the column list for SELECT queries."
		Protected Function Columns() As String
		  Return "id, title, body, created_at, updated_at"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Returns all notes ordered by updated_at DESC."
		Function GetAll() As Variant()
		  Return FindAll("updated_at DESC")
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Returns a single note as a Dictionary, or Nil if not found."
		Function GetByID(id As Integer) As Dictionary
		  Return FindByID(id)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Creates a new note and returns its ID. Uses custom SQL so SQLite sets timestamps via DEFAULT."
		Function Create(title As String, body As String) As Integer
		  Var db As SQLiteDatabase = OpenDB()
		  db.ExecuteSQL("INSERT INTO notes (title, body) VALUES (?, ?)", title, body)
		  Var newID As Integer = db.LastRowID
		  db.Close()
		  Return newID
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Updates title, body, and updated_at for the given note ID."
		Sub Update(id As Integer, title As String, body As String)
		  Var db As SQLiteDatabase = OpenDB()
		  db.ExecuteSQL("UPDATE notes SET title = ?, body = ?, updated_at = datetime('now') WHERE id = ?", title, body, id)
		  db.Close()
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Deletes a note by ID."
		Sub Delete(id As Integer)
		  DeleteByID(id)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Returns all tags for a note as Variant() of Dictionary."
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
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Replaces all tags for a note. Deletes existing associations then inserts new ones."
		Sub SetTagsForNote(noteID As Integer, tagIDs() As Integer)
		  Var db As SQLiteDatabase = OpenDB()
		  db.ExecuteSQL("DELETE FROM note_tags WHERE note_id = ?", noteID)
		  For Each tagID As Integer In tagIDs
		    db.ExecuteSQL("INSERT OR IGNORE INTO note_tags (note_id, tag_id) VALUES (?, ?)", noteID, tagID)
		  Next
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

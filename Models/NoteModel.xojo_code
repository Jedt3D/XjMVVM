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
		  Return "id, title, body, created_at, updated_at, user_id"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Returns all notes for a user ordered by updated_at DESC."
		Function GetAll(userID As Integer) As Variant()
		  Var results() As Variant
		  Var db As SQLiteDatabase = OpenDB()
		  Var sql As String = "SELECT " + Columns() + " FROM notes WHERE user_id = ? ORDER BY updated_at DESC"
		  Var rs As RowSet = db.SelectSQL(sql, userID)
		  While Not rs.AfterLastRow
		    results.Add(RowToDict(rs))
		    rs.MoveToNextRow()
		  Wend
		  rs.Close()
		  db.Close()
		  Return results
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Returns a single note as a Dictionary, or Nil if not found or not owned by user."
		Function GetByID(id As Integer, userID As Integer) As Dictionary
		  Var db As SQLiteDatabase = OpenDB()
		  Var rs As RowSet = db.SelectSQL("SELECT " + Columns() + " FROM notes WHERE id = ? AND user_id = ?", id, userID)
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
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Creates a new note for a user and returns its ID."
		Function Create(title As String, body As String, userID As Integer) As Integer
		  Var db As SQLiteDatabase = OpenDB()
		  db.ExecuteSQL("INSERT INTO notes (title, body, user_id) VALUES (?, ?, ?)", title, body, userID)
		  Var newID As Integer = db.LastRowID
		  db.Close()
		  Return newID
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Updates title, body, and updated_at for the given note ID, scoped by user."
		Sub Update(id As Integer, title As String, body As String, userID As Integer)
		  Var db As SQLiteDatabase = OpenDB()
		  db.ExecuteSQL("UPDATE notes SET title = ?, body = ?, updated_at = datetime('now') WHERE id = ? AND user_id = ?", title, body, id, userID)
		  db.Close()
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Deletes a note by ID, scoped by user."
		Sub Delete(id As Integer, userID As Integer)
		  Var db As SQLiteDatabase = OpenDB()
		  db.ExecuteSQL("DELETE FROM notes WHERE id = ? AND user_id = ?", id, userID)
		  db.Close()
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Returns the total number of notes for a user."
		Function CountForUser(userID As Integer) As Integer
		  Var db As SQLiteDatabase = OpenDB()
		  Var rs As RowSet = db.SelectSQL("SELECT COUNT(*) AS n FROM notes WHERE user_id = ?", userID)
		  Var n As Integer = 0
		  If Not rs.AfterLastRow Then n = rs.Column("n").IntegerValue
		  rs.Close()
		  db.Close()
		  Return n
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Returns a page of notes for a user."
		Function FindPaginatedForUser(userID As Integer, limit As Integer, offset As Integer, orderBy As String = "") As Variant()
		  Var results() As Variant
		  Var db As SQLiteDatabase = OpenDB()
		  Var sql As String = "SELECT " + Columns() + " FROM notes WHERE user_id = ?"
		  If orderBy.Length > 0 Then sql = sql + " ORDER BY " + orderBy
		  sql = sql + " LIMIT ? OFFSET ?"
		  Var rs As RowSet = db.SelectSQL(sql, userID, limit, offset)
		  While Not rs.AfterLastRow
		    results.Add(RowToDict(rs))
		    rs.MoveToNextRow()
		  Wend
		  rs.Close()
		  db.Close()
		  Return results
		End Function
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

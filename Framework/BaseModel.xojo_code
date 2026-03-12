#tag Class
Protected Class BaseModel
	#tag Method, Flags = &h1, Description = "Override in subclass. Returns the table name."
		Protected Function TableName() As String
		  Return ""
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1, Description = "Override in subclass. Returns comma-separated column list, e.g. 'id, title, body'."
		Protected Function Columns() As String
		  Return "id"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1, Description = "Opens a fresh DB connection. Escape hatch for custom SQL in subclasses."
		Protected Function OpenDB() As SQLiteDatabase
		  Return DBAdapter.Connect()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1, Description = "Maps a RowSet row to a Dictionary using Columns(). All values stored as StringValue."
		Protected Function RowToDict(rs As RowSet) As Dictionary
		  Var row As New Dictionary()
		  Var cols() As String = Columns().Split(", ")
		  For Each col As String In cols
		    col = col.Trim()
		    row.Value(col) = rs.Column(col).StringValue
		  Next
		  Return row
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Returns all rows as Variant() of Dictionary. orderBy is an optional SQL ORDER BY clause value."
		Function FindAll(orderBy As String = "") As Variant()
		  Var results() As Variant
		  Var db As SQLiteDatabase = OpenDB()
		  Var sql As String = "SELECT " + Columns() + " FROM " + TableName()
		  If orderBy.Length > 0 Then sql = sql + " ORDER BY " + orderBy
		  Var rs As RowSet = db.SelectSQL(sql)
		  While Not rs.AfterLastRow
		    results.Add(RowToDict(rs))
		    rs.MoveToNextRow()
		  Wend
		  rs.Close()
		  db.Close()
		  Return results
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Returns one row as Dictionary, or Nil if not found."
		Function FindByID(id As Integer) As Dictionary
		  Var db As SQLiteDatabase = OpenDB()
		  Var rs As RowSet = db.SelectSQL("SELECT " + Columns() + " FROM " + TableName() + " WHERE id = ?", id)
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

	#tag Method, Flags = &h0, Description = "Inserts a row from a Dictionary of column→value pairs. Returns the new row ID."
		Function Insert(data As Dictionary) As Integer
		  Var db As SQLiteDatabase = OpenDB()
		  Var cols() As String
		  Var placeholders() As String
		  Var values() As Variant

		  For Each key As Variant In data.Keys
		    cols.Add(key.StringValue)
		    placeholders.Add("?")
		    values.Add(data.Value(key))
		  Next

		  Var sql As String = "INSERT INTO " + TableName() + " (" + String.FromArray(cols, ", ") + ") VALUES (" + String.FromArray(placeholders, ", ") + ")"
		  Var ps As SQLitePreparedStatement = db.Prepare(sql)

		  For i As Integer = 0 To values.Count - 1
		    Var val As Variant = values(i)
		    If val.Type = Variant.TypeString Then
		      ps.BindType(i, SQLitePreparedStatement.SQLITE_TEXT)
		      ps.Bind(i, val.StringValue)
		    Else
		      ps.BindType(i, SQLitePreparedStatement.SQLITE_INTEGER)
		      ps.Bind(i, val.IntegerValue)
		    End If
		  Next

		  ps.SQLExecute()
		  Var newID As Integer = db.LastRowID
		  db.Close()
		  Return newID
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Updates a row by ID from a Dictionary of column→value pairs."
		Sub UpdateByID(id As Integer, data As Dictionary)
		  Var db As SQLiteDatabase = OpenDB()
		  Var setParts() As String
		  Var values() As Variant

		  For Each key As Variant In data.Keys
		    setParts.Add(key.StringValue + " = ?")
		    values.Add(data.Value(key))
		  Next

		  Var sql As String = "UPDATE " + TableName() + " SET " + String.FromArray(setParts, ", ") + " WHERE id = ?"
		  Var ps As SQLitePreparedStatement = db.Prepare(sql)

		  For i As Integer = 0 To values.Count - 1
		    Var val As Variant = values(i)
		    If val.Type = Variant.TypeString Then
		      ps.BindType(i, SQLitePreparedStatement.SQLITE_TEXT)
		      ps.Bind(i, val.StringValue)
		    Else
		      ps.BindType(i, SQLitePreparedStatement.SQLITE_INTEGER)
		      ps.Bind(i, val.IntegerValue)
		    End If
		  Next

		  ps.BindType(values.Count, SQLitePreparedStatement.SQLITE_INTEGER)
		  ps.Bind(values.Count, id)
		  ps.SQLExecute()
		  db.Close()
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Deletes a row by ID."
		Sub DeleteByID(id As Integer)
		  Var db As SQLiteDatabase = OpenDB()
		  db.ExecuteSQL("DELETE FROM " + TableName() + " WHERE id = ?", id)
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

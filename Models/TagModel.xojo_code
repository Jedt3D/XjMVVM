#tag Class
Protected Class TagModel
Inherits BaseModel
	#tag Method, Flags = &h1, Description = "Returns the table name."
		Protected Function TableName() As String
		  Return "tags"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1, Description = "Returns the column list for SELECT queries."
		Protected Function Columns() As String
		  Return "id, name, created_at"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Returns all tags ordered by name ASC."
		Function GetAll() As Variant()
		  Return FindAll("name ASC")
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Returns a single tag as a Dictionary, or Nil if not found."
		Function GetByID(id As Integer) As Dictionary
		  Return FindByID(id)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Creates a new tag and returns its ID."
		Function Create(name As String) As Integer
		  Var db As SQLiteDatabase = OpenDB()
		  db.ExecuteSQL("INSERT INTO tags (name) VALUES (?)", name)
		  Var newID As Integer = db.LastRowID
		  db.Close()
		  Return newID
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Updates the name for the given tag ID."
		Sub Update(id As Integer, name As String)
		  Var db As SQLiteDatabase = OpenDB()
		  db.ExecuteSQL("UPDATE tags SET name = ? WHERE id = ?", name, id)
		  db.Close()
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Deletes a tag by ID."
		Sub Delete(id As Integer)
		  DeleteByID(id)
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

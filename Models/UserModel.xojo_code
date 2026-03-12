#tag Class
Protected Class UserModel
Inherits BaseModel
	#tag Method, Flags = &h1, Description = "Returns the table name."
		Protected Function TableName() As String
		  Return "users"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1, Description = "Returns the column list for SELECT queries."
		Protected Function Columns() As String
		  Return "id, username, password_hash, created_at"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Creates a new user with a hashed password. Returns the new user ID, or 0 if username already exists."
		Function Create(username As String, password As String) As Integer
		  // Check for existing username
		  If FindByUsername(username) <> Nil Then Return 0

		  Var salt As String = GenerateSalt()
		  Var hash As String = HashPassword(password, salt)
		  Var stored As String = hash + ":" + salt

		  Var db As SQLiteDatabase = OpenDB()
		  db.ExecuteSQL("INSERT INTO users (username, password_hash) VALUES (?, ?)", username, stored)
		  Var newID As Integer = db.LastRowID
		  db.Close()
		  Return newID
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Returns the user Dictionary for the given username, or Nil if not found."
		Function FindByUsername(username As String) As Dictionary
		  Var db As SQLiteDatabase = OpenDB()
		  Var rs As RowSet = db.SelectSQL("SELECT " + Columns() + " FROM users WHERE username = ?", username)
		  If rs.AfterLastRow Then
		    rs.Close()
		    db.Close()
		    Return Nil
		  End If
		  Var row As New Dictionary()
		  row.Value("id") = rs.Column("id").StringValue
		  row.Value("username") = rs.Column("username").StringValue
		  row.Value("password_hash") = rs.Column("password_hash").StringValue
		  row.Value("created_at") = rs.Column("created_at").StringValue
		  rs.Close()
		  db.Close()
		  Return row
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Returns True if the username exists and the password matches."
		Function VerifyPassword(username As String, password As String) As Boolean
		  Var row As Dictionary = FindByUsername(username)
		  If row = Nil Then Return False

		  Var stored As String = row.Value("password_hash").StringValue
		  Var colonPos As Integer = stored.IndexOf(":")
		  If colonPos < 0 Then Return False

		  Var hash As String = stored.Left(colonPos)
		  Var salt As String = stored.Middle(colonPos + 1)
		  Return HashPassword(password, salt) = hash
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21, Description = "Returns a random hex salt string."
		Private Function GenerateSalt() As String
		  // Use current time + random number for uniqueness
		  Var raw As String = Str(System.Ticks) + Str(Rnd)
		  Return EncodeHex(Crypto.SHA256(raw))
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21, Description = "Returns hex-encoded SHA-256(password + salt)."
		Private Function HashPassword(password As String, salt As String) As String
		  Return EncodeHex(Crypto.SHA256(password + salt))
		End Function
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

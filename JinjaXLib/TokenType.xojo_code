#tag Module
Protected Module TokenType
	#tag Method, Flags = &h0
		Function TokenName(tokenType As Double) As String
		  Select Case tokenType
		  Case TYPE_EOF
		    Return "EOF"
		  Case TYPE_DATA
		    Return "DATA"
		  Case TYPE_VARIABLE_BEGIN
		    Return "VARIABLE_BEGIN"
		  Case TYPE_VARIABLE_END
		    Return "VARIABLE_END"
		  Case TYPE_BLOCK_BEGIN
		    Return "BLOCK_BEGIN"
		  Case TYPE_BLOCK_END
		    Return "BLOCK_END"
		  Case TYPE_COMMENT_BEGIN
		    Return "COMMENT_BEGIN"
		  Case TYPE_COMMENT_END
		    Return "COMMENT_END"
		  Case TYPE_NAME
		    Return "NAME"
		  Case TYPE_STRING
		    Return "STRING"
		  Case TYPE_INTEGER
		    Return "INTEGER"
		  Case TYPE_FLOAT
		    Return "FLOAT"
		  Case TYPE_OPERATOR
		    Return "OPERATOR"
		  Case TYPE_PIPE
		    Return "PIPE"
		  Case TYPE_DOT
		    Return "DOT"
		  Case TYPE_COMMA
		    Return "COMMA"
		  Case TYPE_COLON
		    Return "COLON"
		  Case TYPE_LPAREN
		    Return "LPAREN"
		  Case TYPE_RPAREN
		    Return "RPAREN"
		  Case TYPE_LBRACKET
		    Return "LBRACKET"
		  Case TYPE_RBRACKET
		    Return "RBRACKET"
		  Case TYPE_ASSIGN
		    Return "ASSIGN"
		  Case TYPE_KEYWORD
		    Return "KEYWORD"
		  Else
		    Return "UNKNOWN"
		  End Select
		End Function
	#tag EndMethod


	#tag Constant, Name = TYPE_ASSIGN, Type = Double, Dynamic = False, Default = \"21", Scope = Public
	#tag EndConstant

	#tag Constant, Name = TYPE_BLOCK_BEGIN, Type = Double, Dynamic = False, Default = \"4", Scope = Public
	#tag EndConstant

	#tag Constant, Name = TYPE_BLOCK_END, Type = Double, Dynamic = False, Default = \"5", Scope = Public
	#tag EndConstant

	#tag Constant, Name = TYPE_COLON, Type = Double, Dynamic = False, Default = \"16", Scope = Public
	#tag EndConstant

	#tag Constant, Name = TYPE_COMMA, Type = Double, Dynamic = False, Default = \"15", Scope = Public
	#tag EndConstant

	#tag Constant, Name = TYPE_COMMENT_BEGIN, Type = Double, Dynamic = False, Default = \"6", Scope = Public
	#tag EndConstant

	#tag Constant, Name = TYPE_COMMENT_END, Type = Double, Dynamic = False, Default = \"7", Scope = Public
	#tag EndConstant

	#tag Constant, Name = TYPE_DATA, Type = Double, Dynamic = False, Default = \"1", Scope = Public
	#tag EndConstant

	#tag Constant, Name = TYPE_DOT, Type = Double, Dynamic = False, Default = \"14", Scope = Public
	#tag EndConstant

	#tag Constant, Name = TYPE_EOF, Type = Double, Dynamic = False, Default = \"0", Scope = Public
	#tag EndConstant

	#tag Constant, Name = TYPE_FLOAT, Type = Double, Dynamic = False, Default = \"11", Scope = Public
	#tag EndConstant

	#tag Constant, Name = TYPE_INTEGER, Type = Double, Dynamic = False, Default = \"10", Scope = Public
	#tag EndConstant

	#tag Constant, Name = TYPE_KEYWORD, Type = Double, Dynamic = False, Default = \"22", Scope = Public
	#tag EndConstant

	#tag Constant, Name = TYPE_LBRACKET, Type = Double, Dynamic = False, Default = \"19", Scope = Public
	#tag EndConstant

	#tag Constant, Name = TYPE_LPAREN, Type = Double, Dynamic = False, Default = \"17", Scope = Public
	#tag EndConstant

	#tag Constant, Name = TYPE_NAME, Type = Double, Dynamic = False, Default = \"8", Scope = Public
	#tag EndConstant

	#tag Constant, Name = TYPE_OPERATOR, Type = Double, Dynamic = False, Default = \"12", Scope = Public
	#tag EndConstant

	#tag Constant, Name = TYPE_PIPE, Type = Double, Dynamic = False, Default = \"13", Scope = Public
	#tag EndConstant

	#tag Constant, Name = TYPE_RBRACKET, Type = Double, Dynamic = False, Default = \"20", Scope = Public
	#tag EndConstant

	#tag Constant, Name = TYPE_RPAREN, Type = Double, Dynamic = False, Default = \"18", Scope = Public
	#tag EndConstant

	#tag Constant, Name = TYPE_STRING, Type = Double, Dynamic = False, Default = \"9", Scope = Public
	#tag EndConstant

	#tag Constant, Name = TYPE_VARIABLE_BEGIN, Type = Double, Dynamic = False, Default = \"2", Scope = Public
	#tag EndConstant

	#tag Constant, Name = TYPE_VARIABLE_END, Type = Double, Dynamic = False, Default = \"3", Scope = Public
	#tag EndConstant


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
End Module
#tag EndModule

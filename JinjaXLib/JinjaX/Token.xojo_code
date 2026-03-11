#tag Class
Protected Class Token
	#tag Method, Flags = &h0
		Sub Constructor(tokenType As Double, tokenValue As String, lineNum As Integer = 1, colNum As Integer = 1)
		  Me.Type = tokenType
		  Me.Value = tokenValue
		  Me.LineNumber = lineNum
		  Me.ColumnNumber = colNum
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function ToString() As String
		  Return "Token(" + TokenType.TokenName(Me.Type) + ", " + Chr(34) + Me.Value + Chr(34) + ", line=" + Me.LineNumber.ToString + ", col=" + Me.ColumnNumber.ToString + ")"
		End Function
	#tag EndMethod


	#tag Property, Flags = &h0
		Type As Double
	#tag EndProperty

	#tag Property, Flags = &h0
		Value As String
	#tag EndProperty

	#tag Property, Flags = &h0
		LineNumber As Integer
	#tag EndProperty

	#tag Property, Flags = &h0
		ColumnNumber As Integer
	#tag EndProperty

End Class
#tag EndClass

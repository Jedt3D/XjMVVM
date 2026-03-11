#tag Class
Protected Class ASTNode
	#tag Method, Flags = &h0
		Sub Constructor()
		  Me.LineNumber = 1
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function NodeType() As String
		  Return "Node"
		End Function
	#tag EndMethod


	#tag Property, Flags = &h0
		LineNumber As Integer = 1
	#tag EndProperty

End Class
#tag EndClass

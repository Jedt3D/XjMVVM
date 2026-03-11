#tag Class
Protected Class SetNode
Inherits ASTNode
	#tag Method, Flags = &h0
		Sub Constructor(variableName As String, value As ASTNode)
		  Super.Constructor()
		  Me.VariableName = variableName
		  Me.Value = value
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function NodeType() As String
		  Return "Set"
		End Function
	#tag EndMethod


	#tag Property, Flags = &h0
		VariableName As String
	#tag EndProperty

	#tag Property, Flags = &h0
		Value As ASTNode
	#tag EndProperty

End Class
#tag EndClass

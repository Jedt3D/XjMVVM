#tag Class
Protected Class OutputNode
Inherits ASTNode
	#tag Method, Flags = &h0
		Sub Constructor(expr As ASTNode)
		  Super.Constructor()
		  Me.Expression = expr
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function NodeType() As String
		  Return "Output"
		End Function
	#tag EndMethod


	#tag Property, Flags = &h0
		Expression As ASTNode
	#tag EndProperty

End Class
#tag EndClass

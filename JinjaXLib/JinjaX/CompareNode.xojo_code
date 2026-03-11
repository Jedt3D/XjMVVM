#tag Class
Protected Class CompareNode
Inherits ASTNode
	#tag Method, Flags = &h0
		Sub Constructor(left As ASTNode, op As String, right As ASTNode)
		  Super.Constructor()
		  Me.Left = left
		  Me.Operator = op
		  Me.Right = right
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function NodeType() As String
		  Return "Compare"
		End Function
	#tag EndMethod


	#tag Property, Flags = &h0
		Left As ASTNode
	#tag EndProperty

	#tag Property, Flags = &h0
		Operator As String
	#tag EndProperty

	#tag Property, Flags = &h0
		Right As ASTNode
	#tag EndProperty

End Class
#tag EndClass

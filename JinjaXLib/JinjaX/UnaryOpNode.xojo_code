#tag Class
Protected Class UnaryOpNode
Inherits ASTNode
	#tag Method, Flags = &h0
		Sub Constructor(op As String, operand As ASTNode)
		  Super.Constructor()
		  Me.Operator = op
		  Me.Operand = operand
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function NodeType() As String
		  Return "UnaryOp"
		End Function
	#tag EndMethod


	#tag Property, Flags = &h0
		Operator As String
	#tag EndProperty

	#tag Property, Flags = &h0
		Operand As ASTNode
	#tag EndProperty

End Class
#tag EndClass

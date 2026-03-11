#tag Class
Protected Class LiteralNode
Inherits ASTNode
	#tag Method, Flags = &h0
		Sub Constructor(val As Variant, literalType As Integer)
		  Super.Constructor()
		  Me.Value = val
		  Me.LiteralType = literalType
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function NodeType() As String
		  Return "Literal"
		End Function
	#tag EndMethod


	#tag Property, Flags = &h0
		Value As Variant
	#tag EndProperty

	#tag Property, Flags = &h0
		LiteralType As Integer
	#tag EndProperty

	#tag Note, Name = LiteralType Constants
		0 = String
		1 = Integer
		2 = Float
		3 = Boolean
		4 = None
	#tag EndNote

End Class
#tag EndClass

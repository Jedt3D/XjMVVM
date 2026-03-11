#tag Class
Protected Class GetAttrNode
Inherits ASTNode
	#tag Method, Flags = &h0
		Sub Constructor(obj As ASTNode, attr As String)
		  Super.Constructor()
		  Me.Obj = obj
		  Me.Attribute = attr
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function NodeType() As String
		  Return "GetAttr"
		End Function
	#tag EndMethod


	#tag Property, Flags = &h0
		Obj As ASTNode
	#tag EndProperty

	#tag Property, Flags = &h0
		Attribute As String
	#tag EndProperty

End Class
#tag EndClass

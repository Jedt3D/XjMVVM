#tag Class
Protected Class GetItemNode
Inherits ASTNode
	#tag Method, Flags = &h0
		Sub Constructor(obj As ASTNode, idx As ASTNode)
		  Super.Constructor()
		  Me.Obj = obj
		  Me.Index = idx
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function NodeType() As String
		  Return "GetItem"
		End Function
	#tag EndMethod


	#tag Property, Flags = &h0
		Obj As ASTNode
	#tag EndProperty

	#tag Property, Flags = &h0
		Index As ASTNode
	#tag EndProperty

End Class
#tag EndClass

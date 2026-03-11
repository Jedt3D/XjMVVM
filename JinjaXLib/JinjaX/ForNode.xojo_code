#tag Class
Protected Class ForNode
Inherits ASTNode
	#tag Method, Flags = &h0
		Sub Constructor(variableName As String, iterable As ASTNode)
		  Super.Constructor()
		  Me.VariableName = variableName
		  Me.Iterable = iterable
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function NodeType() As String
		  Return "For"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub AddBodyNode(node As ASTNode)
		  Me.Body.Add(node)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub AddElseNode(node As ASTNode)
		  Me.ElseBody.Add(node)
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0
		VariableName As String
	#tag EndProperty

	#tag Property, Flags = &h0
		Iterable As ASTNode
	#tag EndProperty

	#tag Property, Flags = &h0
		Body() As ASTNode
	#tag EndProperty

	#tag Property, Flags = &h0
		ElseBody() As ASTNode
	#tag EndProperty

End Class
#tag EndClass

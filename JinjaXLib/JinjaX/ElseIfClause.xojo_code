#tag Class
Protected Class ElseIfClause
	#tag Method, Flags = &h0
		Sub Constructor(condition As ASTNode)
		  Me.Condition = condition
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub AddNode(node As ASTNode)
		  Me.Body.Add(node)
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0
		Condition As ASTNode
	#tag EndProperty

	#tag Property, Flags = &h0
		Body() As ASTNode
	#tag EndProperty

End Class
#tag EndClass

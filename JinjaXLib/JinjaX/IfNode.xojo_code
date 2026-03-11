#tag Class
Protected Class IfNode
Inherits ASTNode
	#tag Method, Flags = &h0
		Sub Constructor(condition As ASTNode)
		  Super.Constructor()
		  Me.Condition = condition
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function NodeType() As String
		  Return "If"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub AddTrueNode(node As ASTNode)
		  Me.TrueBody.Add(node)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub AddElseIf(condition As ASTNode)
		  Var clause As New ElseIfClause(condition)
		  Me.ElseIfClauses.Add(clause)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub AddElseNode(node As ASTNode)
		  Me.ElseBody.Add(node)
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0
		Condition As ASTNode
	#tag EndProperty

	#tag Property, Flags = &h0
		TrueBody() As ASTNode
	#tag EndProperty

	#tag Property, Flags = &h0
		ElseIfClauses() As ElseIfClause
	#tag EndProperty

	#tag Property, Flags = &h0
		ElseBody() As ASTNode
	#tag EndProperty

End Class
#tag EndClass

#tag Class
Protected Class FilterNode
Inherits ASTNode
	#tag Method, Flags = &h0
		Sub Constructor(expr As ASTNode, filterName As String)
		  Super.Constructor()
		  Me.Expression = expr
		  Me.FilterName = filterName
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function NodeType() As String
		  Return "Filter"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub AddArgument(arg As ASTNode)
		  Me.Arguments.Add(arg)
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0
		Expression As ASTNode
	#tag EndProperty

	#tag Property, Flags = &h0
		FilterName As String
	#tag EndProperty

	#tag Property, Flags = &h0
		Arguments() As ASTNode
	#tag EndProperty

End Class
#tag EndClass

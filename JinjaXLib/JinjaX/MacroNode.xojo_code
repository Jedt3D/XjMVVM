#tag Class
Protected Class MacroNode
Inherits ASTNode
	#tag Method, Flags = &h0
		Sub Constructor(name As String)
		  Super.Constructor()
		  Me.Name = name
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function NodeType() As String
		  Return "Macro"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub AddParam(paramName As String)
		  Me.Params.Add(paramName)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub AddBodyNode(node As ASTNode)
		  Me.Body.Add(node)
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0
		Name As String
	#tag EndProperty

	#tag Property, Flags = &h0
		Params() As String
	#tag EndProperty

	#tag Property, Flags = &h0
		Body() As ASTNode
	#tag EndProperty

End Class
#tag EndClass

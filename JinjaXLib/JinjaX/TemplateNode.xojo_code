#tag Class
Protected Class TemplateNode
Inherits ASTNode
	#tag Method, Flags = &h0
		Sub Constructor()
		  Super.Constructor()
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function NodeType() As String
		  Return "Template"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub AddNode(node As ASTNode)
		  Me.Body.Add(node)
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0
		Body() As ASTNode
	#tag EndProperty

End Class
#tag EndClass

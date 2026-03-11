#tag Class
Protected Class IncludeNode
Inherits ASTNode
	#tag Method, Flags = &h0
		Sub Constructor(templateName As String)
		  Super.Constructor()
		  Me.TemplateName = templateName
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function NodeType() As String
		  Return "Include"
		End Function
	#tag EndMethod


	#tag Property, Flags = &h0
		TemplateName As String
	#tag EndProperty

End Class
#tag EndClass

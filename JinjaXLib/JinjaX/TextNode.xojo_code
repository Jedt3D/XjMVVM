#tag Class
Protected Class TextNode
Inherits ASTNode
	#tag Method, Flags = &h0
		Sub Constructor(text As String)
		  Super.Constructor()
		  Me.Text = text
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function NodeType() As String
		  Return "Text"
		End Function
	#tag EndMethod


	#tag Property, Flags = &h0
		Text As String
	#tag EndProperty

End Class
#tag EndClass

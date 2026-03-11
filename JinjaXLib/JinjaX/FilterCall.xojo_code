#tag Class
Protected Class FilterCall
	#tag Method, Flags = &h0
		Sub Constructor(name As String)
		  Me.FilterName = name
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub AddArgument(arg As ASTNode)
		  Me.Arguments.Add(arg)
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0
		FilterName As String
	#tag EndProperty

	#tag Property, Flags = &h0
		Arguments() As ASTNode
	#tag EndProperty

End Class
#tag EndClass

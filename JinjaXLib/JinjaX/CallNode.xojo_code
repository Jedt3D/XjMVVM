#tag Class
Protected Class CallNode
Inherits ASTNode
	#tag Method, Flags = &h0
		Sub Constructor(macroName As String)
		  Super.Constructor()
		  Me.MacroName = macroName
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function NodeType() As String
		  Return "Call"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub AddArgument(arg As ASTNode)
		  Me.Arguments.Add(arg)
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0
		MacroName As String
	#tag EndProperty

	#tag Property, Flags = &h0
		Arguments() As ASTNode
	#tag EndProperty

End Class
#tag EndClass

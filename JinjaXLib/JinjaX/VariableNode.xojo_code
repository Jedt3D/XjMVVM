#tag Class
Protected Class VariableNode
Inherits ASTNode
	#tag Method, Flags = &h0
		Sub Constructor(name As String)
		  Super.Constructor()
		  Me.Name = name
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function NodeType() As String
		  Return "Variable"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub AddFilter(filter As FilterCall)
		  Me.Filters.Add(filter)
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0
		Name As String
	#tag EndProperty

	#tag Property, Flags = &h0
		Filters() As FilterCall
	#tag EndProperty

End Class
#tag EndClass

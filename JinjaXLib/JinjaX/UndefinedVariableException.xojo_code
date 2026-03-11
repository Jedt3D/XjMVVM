#tag Class
Protected Class UndefinedVariableException
Inherits TemplateException
	#tag Method, Flags = &h0
		Sub Constructor(variableName As String)
		  Super.Constructor("Undefined variable: " + variableName)
		  Me.VariableName = variableName
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0
		VariableName As String
	#tag EndProperty

End Class
#tag EndClass

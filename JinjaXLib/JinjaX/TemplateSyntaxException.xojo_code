#tag Class
Protected Class TemplateSyntaxException
Inherits TemplateException
	#tag Method, Flags = &h0
		Sub Constructor(msg As String)
		  Super.Constructor(msg)
		  Me.Source = ""
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Constructor(msg As String, source As String, lineNumber As Integer)
		  Super.Constructor(msg, "", lineNumber)
		  Me.Source = source
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0
		Source As String
	#tag EndProperty

End Class
#tag EndClass

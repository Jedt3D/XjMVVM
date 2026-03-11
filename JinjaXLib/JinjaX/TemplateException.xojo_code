#tag Class
Protected Class TemplateException
Inherits RuntimeException
	#tag Method, Flags = &h0
		Sub Constructor(msg As String)
		  Super.Constructor()
		  Me.Message = msg
		  Me.TemplateName = ""
		  Me.TemplateLineNumber = 0
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Constructor(msg As String, templateName As String, lineNumber As Integer)
		  Super.Constructor()
		  Me.Message = msg
		  Me.TemplateName = templateName
		  Me.TemplateLineNumber = lineNumber
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0
		TemplateName As String
	#tag EndProperty

	#tag Property, Flags = &h0
		TemplateLineNumber As Integer
	#tag EndProperty

End Class
#tag EndClass

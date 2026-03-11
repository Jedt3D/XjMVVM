#tag Class
Protected Class TemplateRenderException
Inherits TemplateException
	#tag Method, Flags = &h0
		Sub Constructor(msg As String)
		  Super.Constructor(msg)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Constructor(msg As String, templateName As String, lineNumber As Integer)
		  Super.Constructor(msg, templateName, lineNumber)
		End Sub
	#tag EndMethod

End Class
#tag EndClass

#tag Class
Protected Class DictLoader
Implements JinjaX.ILoader
	#tag Method, Flags = &h0
		Sub Constructor()
		  mTemplates = New Dictionary()
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Constructor(templates As Dictionary)
		  If templates <> Nil Then
		    mTemplates = templates
		  Else
		    mTemplates = New Dictionary()
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetSource(name As String) As String
		  If mTemplates.HasKey(name) Then
		    Return CStr(mTemplates.Value(name))
		  End If

		  Raise New JinjaX.TemplateException("Template not found: " + name)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function HasTemplate(name As String) As Boolean
		  Return mTemplates.HasKey(name)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub AddTemplate(name As String, source As String)
		  mTemplates.Value(name) = source
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub RemoveTemplate(name As String)
		  If mTemplates.HasKey(name) Then
		    mTemplates.Remove(name)
		  End If
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h21
		Private mTemplates As Dictionary
	#tag EndProperty


	#tag ViewBehavior
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			InitialValue=""
			Type="String"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			InitialValue="-2147483648"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			InitialValue=""
			Type="String"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Left"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Top"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass

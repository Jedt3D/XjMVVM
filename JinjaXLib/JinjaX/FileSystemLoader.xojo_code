#tag Class
Protected Class FileSystemLoader
Implements JinjaX.ILoader
	#tag Method, Flags = &h0, Description = "Creates a FileSystemLoader with an absolute FolderItem path."
		Sub Constructor(basePath As FolderItem)
		  mBasePath = basePath
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Creates a FileSystemLoader with a relative path resolved from App Root Folder (App.ExecutableFile.Parent). Use with CopyFiles build step."
		Sub Constructor(relativePath As String)
		  // Resolve relative to App Root Folder
		  // This is where Xojo's CopyFiles build step places resources (Destination = 0)
		  Var appRoot As FolderItem = App.ExecutableFile.Parent
		  mBasePath = appRoot.Child(relativePath)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetSource(name As String) As String
		  If mBasePath = Nil Or Not mBasePath.Exists Then
		    Raise New JinjaX.TemplateException("Template base path does not exist")
		  End If

		  // Handle subdirectory paths (e.g., "subdir/template.html")
		  Var parts() As String = name.Split("/")
		  Var current As FolderItem = mBasePath
		  For i As Integer = 0 To parts.Count - 1
		    current = current.Child(parts(i))
		    If current = Nil Then
		      Raise New JinjaX.TemplateException("Template not found: " + name)
		    End If
		  Next

		  If Not current.Exists Then
		    Raise New JinjaX.TemplateException("Template not found: " + name)
		  End If

		  Try
		    Var stream As TextInputStream = TextInputStream.Open(current)
		    Var content As String = stream.ReadAll()
		    stream.Close()
		    Return content
		  Catch err As RuntimeException
		    Raise New JinjaX.TemplateException("Failed to read template: " + name)
		  End Try
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function HasTemplate(name As String) As Boolean
		  If mBasePath = Nil Or Not mBasePath.Exists Then Return False

		  Var parts() As String = name.Split("/")
		  Var current As FolderItem = mBasePath
		  For i As Integer = 0 To parts.Count - 1
		    current = current.Child(parts(i))
		    If current = Nil Then Return False
		  Next

		  Return current.Exists
		End Function
	#tag EndMethod


	#tag Property, Flags = &h21
		Private mBasePath As FolderItem
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

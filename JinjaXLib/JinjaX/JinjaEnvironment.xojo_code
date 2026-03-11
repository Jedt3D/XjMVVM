#tag Class
Protected Class JinjaEnvironment
	#tag Method, Flags = &h0
		Sub Constructor()
		  mFilters = New Dictionary()
		  Autoescape = True
		  TrimBlocks = False
		  LStripBlocks = False

		  // Register built-in filters
		  BuiltInFilters.RegisterAll(Me)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub RegisterFilter(name As String, filterFunc As JinjaX.FilterFunc)
		  mFilters.Value(name) = filterFunc
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetFilter(name As String) As JinjaX.FilterFunc
		  If mFilters.HasKey(name) Then
		    Return JinjaX.FilterFunc(mFilters.Value(name))
		  End If
		  Return Nil
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function HasFilter(name As String) As Boolean
		  Return mFilters.HasKey(name)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function FromString(template As String) As JinjaX.CompiledTemplate
		  Var lexer As New JinjaX.JinjaLexer()
		  Var parser As New JinjaX.JinjaParser()

		  Var tokens() As JinjaX.Token = lexer.Tokenize(template)
		  Var ast As JinjaX.TemplateNode = parser.Parse(tokens)

		  // Process inheritance if extends is present
		  Var resolvedAST As JinjaX.TemplateNode = JinjaX.ExtendsResolver.Resolve(ast, Me)

		  Return New JinjaX.CompiledTemplate(Me, resolvedAST)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SetLoader(loader As JinjaX.ILoader)
		  mLoader = loader
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetLoader() As JinjaX.ILoader
		  Return mLoader
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetTemplate(name As String) As JinjaX.CompiledTemplate
		  If mLoader = Nil Then
		    Raise New JinjaX.TemplateException("No loader configured")
		  End If

		  Var source As String = mLoader.GetSource(name)
		  Return FromString(source)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Gets the configured template path (relative to App Root Folder)."
		Function TemplatePath() As String
		  Return mTemplatePath
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Sets the template folder path relative to App Root Folder and auto-configures a FileSystemLoader. One-line setup: env.TemplatePath = ""templates"""
		Sub TemplatePath(Assigns value As String)
		  mTemplatePath = value
		  Var loader As New JinjaX.FileSystemLoader(value)
		  Me.SetLoader(loader)
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0
		Autoescape As Boolean = True
	#tag EndProperty

	#tag Property, Flags = &h0
		TrimBlocks As Boolean = False
	#tag EndProperty

	#tag Property, Flags = &h0
		LStripBlocks As Boolean = False
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mFilters As Dictionary
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mLoader As JinjaX.ILoader
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mTemplatePath As String = ""
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

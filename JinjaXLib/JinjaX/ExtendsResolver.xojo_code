#tag Class
Protected Class ExtendsResolver
	#tag Method, Flags = &h1
		Shared Function Resolve(ast As JinjaX.TemplateNode, env As JinjaX.JinjaEnvironment) As JinjaX.TemplateNode
		  // Check if AST has an ExtendsNode as the first meaningful node
		  Var extendsNode As JinjaX.ExtendsNode = Nil
		  Var bodyNodes() As JinjaX.ASTNode = ast.Body

		  For i As Integer = 0 To bodyNodes.Count - 1
		    If bodyNodes(i) IsA JinjaX.ExtendsNode Then
		      extendsNode = JinjaX.ExtendsNode(bodyNodes(i))
		      Exit
		    End If
		  Next

		  // No inheritance — return AST as-is
		  If extendsNode = Nil Then
		    Return ast
		  End If

		  // Need a loader to resolve parent templates
		  If env.GetLoader() = Nil Then
		    Raise New JinjaX.TemplateException("No loader configured for template inheritance")
		  End If

		  // Load and parse parent template
		  Var parentSource As String = env.GetLoader().GetSource(extendsNode.TemplateName)
		  Var lexer As New JinjaX.JinjaLexer()
		  Var parser As New JinjaX.JinjaParser()
		  Var parentTokens() As JinjaX.Token = lexer.Tokenize(parentSource)
		  Var parentAST As JinjaX.TemplateNode = parser.Parse(parentTokens)

		  // Recursively resolve parent's inheritance first
		  parentAST = Resolve(parentAST, env)

		  // Extract child blocks
		  Var childBlocks As New Dictionary()
		  CollectBlocks(ast, childBlocks)

		  // Replace parent blocks with child blocks
		  Var mergedAST As New JinjaX.TemplateNode()
		  Var parentBody() As JinjaX.ASTNode = parentAST.Body
		  For i As Integer = 0 To parentBody.Count - 1
		    mergedAST.AddNode(MergeNode(parentBody(i), childBlocks))
		  Next

		  Return mergedAST
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Shared Sub CollectBlocks(ast As JinjaX.TemplateNode, blocks As Dictionary)
		  Var bodyNodes() As JinjaX.ASTNode = ast.Body
		  For i As Integer = 0 To bodyNodes.Count - 1
		    If bodyNodes(i) IsA JinjaX.BlockNode Then
		      Var blockNode As JinjaX.BlockNode = JinjaX.BlockNode(bodyNodes(i))
		      blocks.Value(blockNode.Name) = blockNode
		    End If
		  Next
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Shared Function MergeNode(node As JinjaX.ASTNode, childBlocks As Dictionary) As JinjaX.ASTNode
		  If node IsA JinjaX.BlockNode Then
		    Var blockNode As JinjaX.BlockNode = JinjaX.BlockNode(node)
		    If childBlocks.HasKey(blockNode.Name) Then
		      // Child overrides this block
		      Return JinjaX.ASTNode(childBlocks.Value(blockNode.Name))
		    End If
		    // Keep parent's default block content
		    Return node
		  End If

		  // Non-block nodes pass through unchanged
		  Return node
		End Function
	#tag EndMethod


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

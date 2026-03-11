#tag Class
Protected Class JinjaRenderer
	#tag Method, Flags = &h0
		Sub Constructor(env As JinjaX.JinjaEnvironment, ctx As JinjaX.JinjaContext)
		  mEnvironment = env
		  mContext = ctx
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Render(node As JinjaX.TemplateNode) As String
		  Var output As String = ""
		  Var bodyNodes() As ASTNode = node.Body
		  For i As Integer = 0 To bodyNodes.Count - 1
		    output = output + RenderNode(bodyNodes(i))
		  Next
		  Return output
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function RenderNode(node As JinjaX.ASTNode) As String
		  If node IsA JinjaX.TextNode Then
		    Return RenderText(JinjaX.TextNode(node))
		  ElseIf node IsA JinjaX.OutputNode Then
		    Return RenderOutput(JinjaX.OutputNode(node))
		  ElseIf node IsA JinjaX.IfNode Then
		    Return RenderIf(JinjaX.IfNode(node))
		  ElseIf node IsA JinjaX.ForNode Then
		    Return RenderFor(JinjaX.ForNode(node))
		  ElseIf node IsA JinjaX.SetNode Then
		    Return RenderSet(JinjaX.SetNode(node))
		  ElseIf node IsA JinjaX.BlockNode Then
		    Return RenderBlock(JinjaX.BlockNode(node))
		  ElseIf node IsA JinjaX.IncludeNode Then
		    Return RenderInclude(JinjaX.IncludeNode(node))
		  End If
		  Return ""
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function RenderText(node As JinjaX.TextNode) As String
		  Return node.Text
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function RenderOutput(node As JinjaX.OutputNode) As String
		  Var value As Variant = EvaluateExpression(node.Expression)
		  Return AutoEscape(value)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function RenderIf(node As JinjaX.IfNode) As String
		  // Evaluate main condition
		  If IsTruthy(EvaluateExpression(node.Condition)) Then
		    Return RenderNodeList(node.TrueBody)
		  End If

		  // Check elif clauses
		  Var elifClauses() As JinjaX.ElseIfClause = node.ElseIfClauses
		  For i As Integer = 0 To elifClauses.Count - 1
		    If IsTruthy(EvaluateExpression(elifClauses(i).Condition)) Then
		      Return RenderNodeList(elifClauses(i).Body)
		    End If
		  Next

		  // Else branch
		  Return RenderNodeList(node.ElseBody)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function RenderFor(node As JinjaX.ForNode) As String
		  Var iterable As Variant = EvaluateExpression(node.Iterable)
		  Var output As String = ""

		  // Handle array
		  If iterable.IsArray Then
		    Var items() As Variant = ToVariantArray(iterable)

		    If items.Count = 0 Then
		      Return RenderNodeList(node.ElseBody)
		    End If

		    For i As Integer = 0 To items.Count - 1
		      mContext.PushScope()
		      mContext.SetVariable(node.VariableName, items(i))

		      // Set loop variables as a Dictionary for dot-access (loop.index etc.)
		      Var loopDict As New Dictionary()
		      loopDict.Value("index") = i + 1
		      loopDict.Value("index0") = i
		      loopDict.Value("first") = (i = 0)
		      loopDict.Value("last") = (i = items.Count - 1)
		      loopDict.Value("length") = items.Count
		      mContext.SetVariable("loop", loopDict)

		      output = output + RenderNodeList(node.Body)
		      mContext.PopScope()
		    Next
		  Else
		    // Not iterable — render else
		    Return RenderNodeList(node.ElseBody)
		  End If

		  Return output
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function RenderSet(node As JinjaX.SetNode) As String
		  Var value As Variant = EvaluateExpression(node.Value)
		  mContext.SetVariable(node.VariableName, value)
		  Return ""
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function RenderBlock(node As JinjaX.BlockNode) As String
		  Return RenderNodeList(node.Body)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function RenderInclude(node As JinjaX.IncludeNode) As String
		  Var loader As JinjaX.ILoader = mEnvironment.GetLoader()
		  If loader = Nil Then
		    Raise New JinjaX.TemplateException("No loader configured for include")
		  End If

		  Var source As String = loader.GetSource(node.TemplateName)
		  Var lexer As New JinjaX.JinjaLexer()
		  Var parser As New JinjaX.JinjaParser()
		  Var tokens() As JinjaX.Token = lexer.Tokenize(source)
		  Var ast As JinjaX.TemplateNode = parser.Parse(tokens)

		  // Render the included template with the current context
		  Return Render(ast)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function RenderNodeList(nodes() As JinjaX.ASTNode) As String
		  Var output As String = ""
		  For i As Integer = 0 To nodes.Count - 1
		    output = output + RenderNode(nodes(i))
		  Next
		  Return output
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function EvaluateExpression(node As JinjaX.ASTNode) As Variant
		  If node IsA JinjaX.LiteralNode Then
		    Return JinjaX.LiteralNode(node).Value

		  ElseIf node IsA JinjaX.VariableNode Then
		    Var varNode As JinjaX.VariableNode = JinjaX.VariableNode(node)
		    Var value As Variant = mContext.GetVariable(varNode.Name)

		    // Apply inline filters from VariableNode
		    Var filters() As JinjaX.FilterCall = varNode.Filters
		    For i As Integer = 0 To filters.Count - 1
		      value = ApplyFilterCall(value, filters(i))
		    Next
		    Return value

		  ElseIf node IsA JinjaX.FilterNode Then
		    Return EvaluateFilterNode(JinjaX.FilterNode(node))

		  ElseIf node IsA JinjaX.BinaryOpNode Then
		    Return EvaluateBinaryOp(JinjaX.BinaryOpNode(node))

		  ElseIf node IsA JinjaX.UnaryOpNode Then
		    Return EvaluateUnaryOp(JinjaX.UnaryOpNode(node))

		  ElseIf node IsA JinjaX.CompareNode Then
		    Return EvaluateCompare(JinjaX.CompareNode(node))

		  ElseIf node IsA JinjaX.GetAttrNode Then
		    Return EvaluateGetAttr(JinjaX.GetAttrNode(node))

		  ElseIf node IsA JinjaX.GetItemNode Then
		    Return EvaluateGetItem(JinjaX.GetItemNode(node))

		  End If

		  Return Nil
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function EvaluateFilterNode(node As JinjaX.FilterNode) As Variant
		  Var value As Variant = EvaluateExpression(node.Expression)

		  Var filterFunc As JinjaX.FilterFunc = mEnvironment.GetFilter(node.FilterName)
		  If filterFunc = Nil Then
		    Return value
		  End If

		  // Evaluate filter arguments
		  Var args() As Variant
		  Var argNodes() As ASTNode = node.Arguments
		  For i As Integer = 0 To argNodes.Count - 1
		    args.Add(EvaluateExpression(argNodes(i)))
		  Next

		  Return filterFunc.Invoke(value, args)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function ApplyFilterCall(value As Variant, filter As JinjaX.FilterCall) As Variant
		  Var filterFunc As JinjaX.FilterFunc = mEnvironment.GetFilter(filter.FilterName)
		  If filterFunc = Nil Then
		    Return value
		  End If

		  // Evaluate filter arguments
		  Var args() As Variant
		  Var argNodes() As ASTNode = filter.Arguments
		  For i As Integer = 0 To argNodes.Count - 1
		    args.Add(EvaluateExpression(argNodes(i)))
		  Next

		  Return filterFunc.Invoke(value, args)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function EvaluateBinaryOp(node As JinjaX.BinaryOpNode) As Variant
		  Var left As Variant = EvaluateExpression(node.Left)
		  Var right As Variant = EvaluateExpression(node.Right)

		  Select Case node.Operator
		  Case "+"
		    // String concatenation or numeric addition
		    If left.Type = Variant.TypeString Or right.Type = Variant.TypeString Then
		      Return CStr(left) + CStr(right)
		    End If
		    Return CDbl(left) + CDbl(right)
		  Case "-"
		    Return CDbl(left) - CDbl(right)
		  Case "*"
		    Return CDbl(left) * CDbl(right)
		  Case "/"
		    If CDbl(right) = 0 Then Return 0
		    Return CDbl(left) / CDbl(right)
		  Case "//"
		    If CDbl(right) = 0 Then Return 0
		    Return Floor(CDbl(left) / CDbl(right))
		  Case "%"
		    If CDbl(right) = 0 Then Return 0
		    Return CDbl(left) Mod CDbl(right)
		  Case "**"
		    Return Pow(CDbl(left), CDbl(right))
		  Case "~"
		    // String concatenation
		    Return VariantToString(left) + VariantToString(right)
		  Case "and"
		    If IsTruthy(left) Then Return right
		    Return left
		  Case "or"
		    If IsTruthy(left) Then Return left
		    Return right
		  End Select

		  Return Nil
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function EvaluateUnaryOp(node As JinjaX.UnaryOpNode) As Variant
		  Var operand As Variant = EvaluateExpression(node.Operand)

		  Select Case node.Operator
		  Case "not"
		    Return Not IsTruthy(operand)
		  Case "-"
		    Return -CDbl(operand)
		  Case "+"
		    Return CDbl(operand)
		  End Select

		  Return Nil
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function EvaluateCompare(node As JinjaX.CompareNode) As Variant
		  Var left As Variant = EvaluateExpression(node.Left)
		  Var right As Variant = EvaluateExpression(node.Right)

		  Select Case node.Operator
		  Case "=="
		    Return VariantsEqual(left, right)
		  Case "!="
		    Return Not VariantsEqual(left, right)
		  Case "<"
		    Return CDbl(left) < CDbl(right)
		  Case ">"
		    Return CDbl(left) > CDbl(right)
		  Case "<="
		    Return CDbl(left) <= CDbl(right)
		  Case ">="
		    Return CDbl(left) >= CDbl(right)
		  Case "in"
		    Return CheckInOperator(left, right)
		  Case "not in"
		    Return Not CheckInOperator(left, right)
		  End Select

		  Return False
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function EvaluateGetAttr(node As JinjaX.GetAttrNode) As Variant
		  Var obj As Variant = EvaluateExpression(node.Obj)

		  // Dictionary dot access
		  If obj IsA Dictionary Then
		    Var dict As Dictionary = Dictionary(obj)
		    If dict.HasKey(node.Attribute) Then
		      Return dict.Value(node.Attribute)
		    End If
		  End If

		  Return Nil
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function EvaluateGetItem(node As JinjaX.GetItemNode) As Variant
		  Var obj As Variant = EvaluateExpression(node.Obj)
		  Var idx As Variant = EvaluateExpression(node.Index)

		  // Dictionary bracket access
		  If obj IsA Dictionary Then
		    Var dict As Dictionary = Dictionary(obj)
		    Var key As String = CStr(idx)
		    If dict.HasKey(key) Then
		      Return dict.Value(key)
		    End If
		  End If

		  Return Nil
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function AutoEscape(value As Variant) As String
		  If value.Type = Variant.TypeNil Then Return ""

		  // If already a MarkupString, don't double-escape
		  If value IsA MarkupSafe.MarkupString Then
		    Return MarkupSafe.MarkupString(value).ToString()
		  End If

		  Var s As String = VariantToString(value)

		  If mEnvironment.Autoescape Then
		    Return MarkupSafe.EscapeString(s)
		  End If

		  Return s
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function IsTruthy(value As Variant) As Boolean
		  If value.Type = Variant.TypeNil Then Return False

		  If value.Type = Variant.TypeBoolean Then
		    Return value.BooleanValue
		  End If

		  If value.Type = Variant.TypeString Then
		    Return CStr(value).Length > 0
		  End If

		  If value.Type = Variant.TypeInteger Or value.Type = Variant.TypeInt64 Then
		    Return value.IntegerValue <> 0
		  End If

		  If value.Type = Variant.TypeDouble Or value.Type = Variant.TypeSingle Then
		    Return CDbl(value) <> 0.0
		  End If

		  // Objects are truthy
		  Return True
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function VariantToString(value As Variant) As String
		  If value.Type = Variant.TypeNil Then Return ""

		  If value IsA MarkupSafe.MarkupString Then
		    Return MarkupSafe.MarkupString(value).ToString()
		  End If

		  If value.Type = Variant.TypeBoolean Then
		    If value.BooleanValue Then Return "True"
		    Return "False"
		  End If

		  Try
		    Return value.StringValue
		  Catch
		    Return ""
		  End Try
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function VariantsEqual(a As Variant, b As Variant) As Boolean
		  If a.Type = Variant.TypeNil And b.Type = Variant.TypeNil Then Return True
		  If a.Type = Variant.TypeNil Or b.Type = Variant.TypeNil Then Return False

		  // String comparison
		  If a.Type = Variant.TypeString Or b.Type = Variant.TypeString Then
		    Return CStr(a) = CStr(b)
		  End If

		  // Numeric comparison
		  Try
		    Return CDbl(a) = CDbl(b)
		  Catch
		    Return False
		  End Try
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function CheckInOperator(needle As Variant, haystack As Variant) As Boolean
		  // String contains
		  If haystack.Type = Variant.TypeString Then
		    Return CStr(haystack).IndexOf(CStr(needle)) >= 0
		  End If

		  // Array contains
		  If haystack.IsArray Then
		    Var items() As Variant = ToVariantArray(haystack)
		    For i As Integer = 0 To items.Count - 1
		      If VariantsEqual(items(i), needle) Then Return True
		    Next
		  End If

		  Return False
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function ToVariantArray(value As Variant) As Variant()
		  Var empty() As Variant

		  If Not value.IsArray Then Return empty

		  // Try direct Variant() assignment (uses separate variable to avoid corruption)
		  Try
		    Var directResult() As Variant = value
		    Return directResult
		  Catch e As RuntimeException
		  End Try

		  // Handle String() arrays
		  Try
		    Var strArr() As String = value
		    Var strResult() As Variant
		    For i As Integer = 0 To strArr.Count - 1
		      strResult.Add(strArr(i))
		    Next
		    Return strResult
		  Catch e As RuntimeException
		  End Try

		  // Handle Integer() arrays
		  Try
		    Var intArr() As Integer = value
		    Var intResult() As Variant
		    For i As Integer = 0 To intArr.Count - 1
		      intResult.Add(intArr(i))
		    Next
		    Return intResult
		  Catch e As RuntimeException
		  End Try

		  // Handle Double() arrays
		  Try
		    Var dblArr() As Double = value
		    Var dblResult() As Variant
		    For i As Integer = 0 To dblArr.Count - 1
		      dblResult.Add(dblArr(i))
		    Next
		    Return dblResult
		  Catch e As RuntimeException
		  End Try

		  Return empty
		End Function
	#tag EndMethod


	#tag Property, Flags = &h21
		Private mEnvironment As JinjaX.JinjaEnvironment
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mContext As JinjaX.JinjaContext
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

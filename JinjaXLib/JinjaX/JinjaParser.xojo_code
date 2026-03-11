#tag Class
Protected Class JinjaParser
	#tag Method, Flags = &h0
		Sub Constructor()
		  // Initialize parser
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Parse(tokens() As JinjaX.Token) As JinjaX.TemplateNode
		  mTokens = tokens
		  mPosition = 0

		  Var root As New JinjaX.TemplateNode()

		  While Not IsAtEnd()
		    If CurrentToken().Type = TokenType.TYPE_DATA Then
		      root.AddNode(ParseTextNode())
		    ElseIf CurrentToken().Type = TokenType.TYPE_VARIABLE_BEGIN Then
		      root.AddNode(ParseOutputNode())
		    ElseIf CurrentToken().Type = TokenType.TYPE_BLOCK_BEGIN Then
		      Var blockNode As JinjaX.ASTNode = ParseBlockStatement()
		      If blockNode <> Nil Then
		        root.AddNode(blockNode)
		      End If
		    Else
		      Advance()
		    End If
		  Wend

		  Return root
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParseTextNode() As JinjaX.ASTNode
		  Var token As JinjaX.Token = CurrentToken()
		  Advance()
		  Return New JinjaX.TextNode(token.Value)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParseOutputNode() As JinjaX.ASTNode
		  Call Expect(TokenType.TYPE_VARIABLE_BEGIN)

		  Var expr As JinjaX.ASTNode = ParseExpression()

		  Call Expect(TokenType.TYPE_VARIABLE_END)

		  Return New JinjaX.OutputNode(expr)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParseBlockStatement() As JinjaX.ASTNode
		  Call Expect(TokenType.TYPE_BLOCK_BEGIN)

		  If CurrentToken().Type = TokenType.TYPE_KEYWORD Then
		    Var keyword As String = CurrentToken().Value.Lowercase()

		    Select Case keyword
		    Case "if"
		      Return ParseIfStatement()
		    Case "for"
		      Return ParseForStatement()
		    Case "block"
		      Return ParseBlockDefinition()
		    Case "extends"
		      Return ParseExtendsStatement()
		    Case "set"
		      Return ParseSetStatement()
		    Case "include"
		      Return ParseIncludeStatement()
		    Case "macro"
		      Return ParseMacroStatement()
		    Case "call"
		      Return ParseCallStatement()
		    Case Else
		      // Unknown keyword, skip to block end
		      SkipToBlockEnd()
		      Return Nil
		    End Select
		  ElseIf CurrentToken().Type = TokenType.TYPE_NAME Then
		    // Possibly a NAME used like a statement, skip to block end
		    SkipToBlockEnd()
		    Return Nil
		  Else
		    SkipToBlockEnd()
		    Return Nil
		  End If
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParseIfStatement() As JinjaX.ASTNode
		  Advance() // Skip 'if' keyword

		  Var condition As JinjaX.ASTNode = ParseExpression()
		  Call Expect(TokenType.TYPE_BLOCK_END)

		  Var ifNode As New JinjaX.IfNode(condition)

		  // Parse if body
		  While Not IsAtEnd() And Not IsEndKeyword("elif") And Not IsEndKeyword("else") And Not IsEndKeyword("endif")
		    If CurrentToken().Type = TokenType.TYPE_DATA Then
		      ifNode.AddTrueNode(ParseTextNode())
		    ElseIf CurrentToken().Type = TokenType.TYPE_VARIABLE_BEGIN Then
		      ifNode.AddTrueNode(ParseOutputNode())
		    ElseIf CurrentToken().Type = TokenType.TYPE_BLOCK_BEGIN Then
		      // Peek ahead to see if next keyword is elif/else/endif
		      If PeekBlockKeyword() = "elif" Or PeekBlockKeyword() = "else" Or PeekBlockKeyword() = "endif" Then
		        Exit
		      End If
		      Var nested As JinjaX.ASTNode = ParseBlockStatement()
		      If nested <> Nil Then
		        ifNode.AddTrueNode(nested)
		      End If
		    Else
		      Advance()
		    End If
		  Wend

		  // Parse elif clauses
		  While IsBlockKeyword("elif")
		    Call Expect(TokenType.TYPE_BLOCK_BEGIN)
		    Advance() // Skip 'elif' keyword

		    Var elifCondition As JinjaX.ASTNode = ParseExpression()
		    Call Expect(TokenType.TYPE_BLOCK_END)

		    // Create an ElseIfClause via IfNode.AddElseIf
		    ifNode.AddElseIf(elifCondition)
		    Var clauseIdx As Integer = ifNode.ElseIfClauses.Count - 1
		    Var clause As JinjaX.ElseIfClause = ifNode.ElseIfClauses(clauseIdx)

		    // Parse elif body
		    While Not IsAtEnd() And Not IsBlockKeyword("elif") And Not IsBlockKeyword("else") And Not IsBlockKeyword("endif")
		      If CurrentToken().Type = TokenType.TYPE_DATA Then
		        clause.AddNode(ParseTextNode())
		      ElseIf CurrentToken().Type = TokenType.TYPE_VARIABLE_BEGIN Then
		        clause.AddNode(ParseOutputNode())
		      ElseIf CurrentToken().Type = TokenType.TYPE_BLOCK_BEGIN Then
		        If PeekBlockKeyword() = "elif" Or PeekBlockKeyword() = "else" Or PeekBlockKeyword() = "endif" Then
		          Exit
		        End If
		        Var nested As JinjaX.ASTNode = ParseBlockStatement()
		        If nested <> Nil Then
		          clause.AddNode(nested)
		        End If
		      Else
		        Advance()
		      End If
		    Wend
		  Wend

		  // Parse else clause
		  If IsBlockKeyword("else") Then
		    Call Expect(TokenType.TYPE_BLOCK_BEGIN)
		    Advance() // Skip 'else' keyword
		    Call Expect(TokenType.TYPE_BLOCK_END)

		    // Parse else body
		    While Not IsAtEnd() And Not IsBlockKeyword("endif")
		      If CurrentToken().Type = TokenType.TYPE_DATA Then
		        ifNode.AddElseNode(ParseTextNode())
		      ElseIf CurrentToken().Type = TokenType.TYPE_VARIABLE_BEGIN Then
		        ifNode.AddElseNode(ParseOutputNode())
		      ElseIf CurrentToken().Type = TokenType.TYPE_BLOCK_BEGIN Then
		        If PeekBlockKeyword() = "endif" Then
		          Exit
		        End If
		        Var nested As JinjaX.ASTNode = ParseBlockStatement()
		        If nested <> Nil Then
		          ifNode.AddElseNode(nested)
		        End If
		      Else
		        Advance()
		      End If
		    Wend
		  End If

		  // Expect {% endif %}
		  Call Expect(TokenType.TYPE_BLOCK_BEGIN)
		  ExpectKeyword("endif")
		  Call Expect(TokenType.TYPE_BLOCK_END)

		  Return ifNode
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParseForStatement() As JinjaX.ASTNode
		  Advance() // Skip 'for' keyword

		  Var varName As String = ExpectName().Value
		  ExpectKeyword("in")
		  Var iterable As JinjaX.ASTNode = ParseExpression()
		  Call Expect(TokenType.TYPE_BLOCK_END)

		  Var forNode As New JinjaX.ForNode(varName, iterable)

		  // Parse body
		  While Not IsAtEnd() And Not IsBlockKeyword("else") And Not IsBlockKeyword("endfor")
		    If CurrentToken().Type = TokenType.TYPE_DATA Then
		      forNode.AddBodyNode(ParseTextNode())
		    ElseIf CurrentToken().Type = TokenType.TYPE_VARIABLE_BEGIN Then
		      forNode.AddBodyNode(ParseOutputNode())
		    ElseIf CurrentToken().Type = TokenType.TYPE_BLOCK_BEGIN Then
		      If PeekBlockKeyword() = "else" Or PeekBlockKeyword() = "endfor" Then
		        Exit
		      End If
		      Var nested As JinjaX.ASTNode = ParseBlockStatement()
		      If nested <> Nil Then
		        forNode.AddBodyNode(nested)
		      End If
		    Else
		      Advance()
		    End If
		  Wend

		  // Parse optional else clause
		  If IsBlockKeyword("else") Then
		    Call Expect(TokenType.TYPE_BLOCK_BEGIN)
		    Advance() // Skip 'else' keyword
		    Call Expect(TokenType.TYPE_BLOCK_END)

		    While Not IsAtEnd() And Not IsBlockKeyword("endfor")
		      If CurrentToken().Type = TokenType.TYPE_DATA Then
		        forNode.AddElseNode(ParseTextNode())
		      ElseIf CurrentToken().Type = TokenType.TYPE_VARIABLE_BEGIN Then
		        forNode.AddElseNode(ParseOutputNode())
		      ElseIf CurrentToken().Type = TokenType.TYPE_BLOCK_BEGIN Then
		        If PeekBlockKeyword() = "endfor" Then
		          Exit
		        End If
		        Var nested As JinjaX.ASTNode = ParseBlockStatement()
		        If nested <> Nil Then
		          forNode.AddElseNode(nested)
		        End If
		      Else
		        Advance()
		      End If
		    Wend
		  End If

		  // Expect {% endfor %}
		  Call Expect(TokenType.TYPE_BLOCK_BEGIN)
		  ExpectKeyword("endfor")
		  Call Expect(TokenType.TYPE_BLOCK_END)

		  Return forNode
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParseBlockDefinition() As JinjaX.ASTNode
		  Advance() // Skip 'block' keyword

		  Var blockName As String = ExpectName().Value
		  Call Expect(TokenType.TYPE_BLOCK_END)

		  Var blockNode As New JinjaX.BlockNode(blockName)

		  // Parse body
		  While Not IsAtEnd() And Not IsBlockKeyword("endblock")
		    If CurrentToken().Type = TokenType.TYPE_DATA Then
		      blockNode.AddBodyNode(ParseTextNode())
		    ElseIf CurrentToken().Type = TokenType.TYPE_VARIABLE_BEGIN Then
		      blockNode.AddBodyNode(ParseOutputNode())
		    ElseIf CurrentToken().Type = TokenType.TYPE_BLOCK_BEGIN Then
		      If PeekBlockKeyword() = "endblock" Then
		        Exit
		      End If
		      Var nested As JinjaX.ASTNode = ParseBlockStatement()
		      If nested <> Nil Then
		        blockNode.AddBodyNode(nested)
		      End If
		    Else
		      Advance()
		    End If
		  Wend

		  // Expect {% endblock %}
		  Call Expect(TokenType.TYPE_BLOCK_BEGIN)
		  ExpectKeyword("endblock")
		  // Optional block name after endblock
		  If CurrentToken().Type = TokenType.TYPE_NAME Then
		    Advance()
		  End If
		  Call Expect(TokenType.TYPE_BLOCK_END)

		  Return blockNode
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParseExtendsStatement() As JinjaX.ASTNode
		  Advance() // Skip 'extends' keyword

		  Var templateName As String
		  If CurrentToken().Type = TokenType.TYPE_STRING Then
		    templateName = CurrentToken().Value
		    Advance()
		  Else
		    Raise New JinjaX.TemplateSyntaxException("extends requires a string template name")
		  End If

		  Call Expect(TokenType.TYPE_BLOCK_END)

		  Return New JinjaX.ExtendsNode(templateName)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParseSetStatement() As JinjaX.ASTNode
		  Advance() // Skip 'set' keyword

		  Var varName As String = ExpectName().Value
		  Call Expect(TokenType.TYPE_ASSIGN)
		  Var value As JinjaX.ASTNode = ParseExpression()
		  Call Expect(TokenType.TYPE_BLOCK_END)

		  Return New JinjaX.SetNode(varName, value)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParseIncludeStatement() As JinjaX.ASTNode
		  Advance() // Skip 'include' keyword

		  Var templateName As String
		  If CurrentToken().Type = TokenType.TYPE_STRING Then
		    templateName = CurrentToken().Value
		    Advance()
		  Else
		    Raise New JinjaX.TemplateSyntaxException("include requires a string template name")
		  End If

		  Call Expect(TokenType.TYPE_BLOCK_END)

		  Return New JinjaX.IncludeNode(templateName)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParseMacroStatement() As JinjaX.ASTNode
		  Advance() // Skip 'macro' keyword

		  Var macroName As String = ExpectName().Value
		  Var macroNode As New JinjaX.MacroNode(macroName)

		  // Parse parameters
		  If CurrentToken().Type = TokenType.TYPE_LPAREN Then
		    Advance()
		    While CurrentToken().Type <> TokenType.TYPE_RPAREN And Not IsAtEnd()
		      If CurrentToken().Type = TokenType.TYPE_NAME Then
		        macroNode.AddParam(CurrentToken().Value)
		        Advance()
		      End If
		      If CurrentToken().Type = TokenType.TYPE_COMMA Then
		        Advance()
		      End If
		    Wend
		    Call Expect(TokenType.TYPE_RPAREN)
		  End If

		  Call Expect(TokenType.TYPE_BLOCK_END)

		  // Parse body
		  While Not IsAtEnd() And Not IsBlockKeyword("endmacro")
		    If CurrentToken().Type = TokenType.TYPE_DATA Then
		      macroNode.AddBodyNode(ParseTextNode())
		    ElseIf CurrentToken().Type = TokenType.TYPE_VARIABLE_BEGIN Then
		      macroNode.AddBodyNode(ParseOutputNode())
		    ElseIf CurrentToken().Type = TokenType.TYPE_BLOCK_BEGIN Then
		      If PeekBlockKeyword() = "endmacro" Then
		        Exit
		      End If
		      Var nested As JinjaX.ASTNode = ParseBlockStatement()
		      If nested <> Nil Then
		        macroNode.AddBodyNode(nested)
		      End If
		    Else
		      Advance()
		    End If
		  Wend

		  // Expect {% endmacro %}
		  Call Expect(TokenType.TYPE_BLOCK_BEGIN)
		  ExpectKeyword("endmacro")
		  Call Expect(TokenType.TYPE_BLOCK_END)

		  Return macroNode
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParseCallStatement() As JinjaX.ASTNode
		  Advance() // Skip 'call' keyword

		  Var macroName As String = ExpectName().Value
		  Var callNode As New JinjaX.CallNode(macroName)

		  // Parse arguments
		  If CurrentToken().Type = TokenType.TYPE_LPAREN Then
		    Advance()
		    While CurrentToken().Type <> TokenType.TYPE_RPAREN And Not IsAtEnd()
		      callNode.AddArgument(ParseExpression())
		      If CurrentToken().Type = TokenType.TYPE_COMMA Then
		        Advance()
		      End If
		    Wend
		    Call Expect(TokenType.TYPE_RPAREN)
		  End If

		  Call Expect(TokenType.TYPE_BLOCK_END)

		  // Skip call body (not storing it as CallNode doesn't have a body array)
		  While Not IsAtEnd() And Not IsBlockKeyword("endcall")
		    If CurrentToken().Type = TokenType.TYPE_BLOCK_BEGIN Then
		      If PeekBlockKeyword() = "endcall" Then
		        Exit
		      End If
		    End If
		    Advance()
		  Wend

		  // Expect {% endcall %}
		  Call Expect(TokenType.TYPE_BLOCK_BEGIN)
		  ExpectKeyword("endcall")
		  Call Expect(TokenType.TYPE_BLOCK_END)

		  Return callNode
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParseExpression() As JinjaX.ASTNode
		  Return ParseOrExpression()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParseOrExpression() As JinjaX.ASTNode
		  Var left As JinjaX.ASTNode = ParseAndExpression()

		  While CurrentToken().Type = TokenType.TYPE_KEYWORD And CurrentToken().Value.Lowercase() = "or"
		    Advance()
		    Var right As JinjaX.ASTNode = ParseAndExpression()
		    left = New JinjaX.BinaryOpNode(left, "or", right)
		  Wend

		  Return left
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParseAndExpression() As JinjaX.ASTNode
		  Var left As JinjaX.ASTNode = ParseNotExpression()

		  While CurrentToken().Type = TokenType.TYPE_KEYWORD And CurrentToken().Value.Lowercase() = "and"
		    Advance()
		    Var right As JinjaX.ASTNode = ParseNotExpression()
		    left = New JinjaX.BinaryOpNode(left, "and", right)
		  Wend

		  Return left
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParseNotExpression() As JinjaX.ASTNode
		  If CurrentToken().Type = TokenType.TYPE_KEYWORD And CurrentToken().Value.Lowercase() = "not" Then
		    Advance()
		    Var operand As JinjaX.ASTNode = ParseNotExpression()
		    Return New JinjaX.UnaryOpNode("not", operand)
		  End If

		  Return ParseComparisonExpression()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParseComparisonExpression() As JinjaX.ASTNode
		  Var left As JinjaX.ASTNode = ParseAdditiveExpression()

		  While True
		    If CurrentToken().Type = TokenType.TYPE_OPERATOR Then
		      Var op As String = CurrentToken().Value
		      If op = "==" Or op = "!=" Or op = "<" Or op = ">" Or op = "<=" Or op = ">=" Then
		        Advance()
		        Var right As JinjaX.ASTNode = ParseAdditiveExpression()
		        left = New JinjaX.CompareNode(left, op, right)
		      Else
		        Exit
		      End If
		    ElseIf CurrentToken().Type = TokenType.TYPE_KEYWORD Then
		      Var kw As String = CurrentToken().Value.Lowercase()
		      If kw = "in" Then
		        Advance()
		        Var right As JinjaX.ASTNode = ParseAdditiveExpression()
		        left = New JinjaX.CompareNode(left, "in", right)
		      ElseIf kw = "not" Then
		        // Check for "not in"
		        If mPosition + 1 < mTokens.Count Then
		          If mTokens(mPosition + 1).Type = TokenType.TYPE_KEYWORD And mTokens(mPosition + 1).Value.Lowercase() = "in" Then
		            Advance() // Skip 'not'
		            Advance() // Skip 'in'
		            Var right As JinjaX.ASTNode = ParseAdditiveExpression()
		            left = New JinjaX.CompareNode(left, "not in", right)
		          Else
		            Exit
		          End If
		        Else
		          Exit
		        End If
		      ElseIf kw = "is" Then
		        Advance() // Skip 'is'
		        // Check for "is not"
		        If CurrentToken().Type = TokenType.TYPE_KEYWORD And CurrentToken().Value.Lowercase() = "not" Then
		          Advance() // Skip 'not'
		          Var right As JinjaX.ASTNode = ParseAdditiveExpression()
		          left = New JinjaX.CompareNode(left, "is not", right)
		        Else
		          Var right As JinjaX.ASTNode = ParseAdditiveExpression()
		          left = New JinjaX.CompareNode(left, "is", right)
		        End If
		      Else
		        Exit
		      End If
		    Else
		      Exit
		    End If
		  Wend

		  Return left
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParseAdditiveExpression() As JinjaX.ASTNode
		  Var left As JinjaX.ASTNode = ParseMultiplicativeExpression()

		  While CurrentToken().Type = TokenType.TYPE_OPERATOR And _
		    (CurrentToken().Value = "+" Or CurrentToken().Value = "-" Or CurrentToken().Value = "~")
		    Var op As String = CurrentToken().Value
		    Advance()
		    Var right As JinjaX.ASTNode = ParseMultiplicativeExpression()
		    left = New JinjaX.BinaryOpNode(left, op, right)
		  Wend

		  Return left
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParseMultiplicativeExpression() As JinjaX.ASTNode
		  Var left As JinjaX.ASTNode = ParseUnaryExpression()

		  While CurrentToken().Type = TokenType.TYPE_OPERATOR And _
		    (CurrentToken().Value = "*" Or CurrentToken().Value = "/" Or _
		    CurrentToken().Value = "//" Or CurrentToken().Value = "%" Or _
		    CurrentToken().Value = "**")
		    Var op As String = CurrentToken().Value
		    Advance()
		    Var right As JinjaX.ASTNode = ParseUnaryExpression()
		    left = New JinjaX.BinaryOpNode(left, op, right)
		  Wend

		  Return left
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParseUnaryExpression() As JinjaX.ASTNode
		  // Handle unary minus
		  If CurrentToken().Type = TokenType.TYPE_OPERATOR And CurrentToken().Value = "-" Then
		    Advance()
		    Var operand As JinjaX.ASTNode = ParsePostfixExpression()
		    Return New JinjaX.UnaryOpNode("-", operand)
		  End If

		  // Handle unary plus (just pass through)
		  If CurrentToken().Type = TokenType.TYPE_OPERATOR And CurrentToken().Value = "+" Then
		    Advance()
		    Return ParsePostfixExpression()
		  End If

		  Return ParsePostfixExpression()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParsePostfixExpression() As JinjaX.ASTNode
		  Var expr As JinjaX.ASTNode = ParsePrimaryExpression()

		  While True
		    If CurrentToken().Type = TokenType.TYPE_DOT Then
		      Advance()
		      Var attr As String = ExpectName().Value
		      expr = New JinjaX.GetAttrNode(expr, attr)

		    ElseIf CurrentToken().Type = TokenType.TYPE_LBRACKET Then
		      Advance()
		      Var idx As JinjaX.ASTNode = ParseExpression()
		      Call Expect(TokenType.TYPE_RBRACKET)
		      expr = New JinjaX.GetItemNode(expr, idx)

		    ElseIf CurrentToken().Type = TokenType.TYPE_PIPE Then
		      Advance()
		      Var filterName As String = ExpectName().Value
		      Var filterNode As New JinjaX.FilterNode(expr, filterName)

		      // Parse filter arguments if present
		      If CurrentToken().Type = TokenType.TYPE_LPAREN Then
		        Advance()
		        While CurrentToken().Type <> TokenType.TYPE_RPAREN And Not IsAtEnd()
		          filterNode.AddArgument(ParseExpression())
		          If CurrentToken().Type = TokenType.TYPE_COMMA Then
		            Advance()
		          End If
		        Wend
		        Call Expect(TokenType.TYPE_RPAREN)
		      End If

		      expr = filterNode

		    ElseIf CurrentToken().Type = TokenType.TYPE_LPAREN Then
		      // Function call: name(args)
		      // expr is already a VariableNode or similar
		      Advance()
		      Var callNode As New JinjaX.CallNode("")

		      // Use expression as the function name if it's a VariableNode
		      If expr IsA JinjaX.VariableNode Then
		        callNode = New JinjaX.CallNode(JinjaX.VariableNode(expr).Name)
		      End If

		      While CurrentToken().Type <> TokenType.TYPE_RPAREN And Not IsAtEnd()
		        callNode.AddArgument(ParseExpression())
		        If CurrentToken().Type = TokenType.TYPE_COMMA Then
		          Advance()
		        End If
		      Wend
		      Call Expect(TokenType.TYPE_RPAREN)

		      expr = callNode

		    Else
		      Exit
		    End If
		  Wend

		  Return expr
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParsePrimaryExpression() As JinjaX.ASTNode
		  If CurrentToken().Type = TokenType.TYPE_NAME Then
		    Var name As String = CurrentToken().Value
		    Advance()
		    Return New JinjaX.VariableNode(name)

		  ElseIf CurrentToken().Type = TokenType.TYPE_STRING Then
		    Var str As String = CurrentToken().Value
		    Advance()
		    Return New JinjaX.LiteralNode(str, 0)

		  ElseIf CurrentToken().Type = TokenType.TYPE_INTEGER Then
		    Var intVal As Integer = Integer.FromString(CurrentToken().Value)
		    Advance()
		    Return New JinjaX.LiteralNode(intVal, 1)

		  ElseIf CurrentToken().Type = TokenType.TYPE_FLOAT Then
		    Var floatVal As Double = CDbl(CurrentToken().Value)
		    Advance()
		    Return New JinjaX.LiteralNode(floatVal, 2)

		  ElseIf CurrentToken().Type = TokenType.TYPE_KEYWORD Then
		    Var kw As String = CurrentToken().Value.Lowercase()
		    If kw = "true" Then
		      Advance()
		      Return New JinjaX.LiteralNode(True, 3)
		    ElseIf kw = "false" Then
		      Advance()
		      Return New JinjaX.LiteralNode(False, 3)
		    ElseIf kw = "none" Then
		      Advance()
		      Return New JinjaX.LiteralNode(Nil, 4)
		    End If

		    // If it's another keyword like "in", fall through to error
		    Raise New JinjaX.TemplateSyntaxException("Unexpected keyword: " + CurrentToken().Value)

		  ElseIf CurrentToken().Type = TokenType.TYPE_LPAREN Then
		    Advance()
		    Var expr As JinjaX.ASTNode = ParseExpression()
		    Call Expect(TokenType.TYPE_RPAREN)
		    Return expr

		  ElseIf CurrentToken().Type = TokenType.TYPE_LBRACKET Then
		    // List literal [a, b, c]
		    Return ParseListLiteral()

		  End If

		  Raise New JinjaX.TemplateSyntaxException("Unexpected token: " + TokenType.TokenName(CurrentToken().Type) + " '" + CurrentToken().Value + "'")
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParseListLiteral() As JinjaX.ASTNode
		  Advance() // Skip '['

		  // Create a CallNode named "__list__" to represent list literals
		  Var listNode As New JinjaX.CallNode("__list__")

		  While CurrentToken().Type <> TokenType.TYPE_RBRACKET And Not IsAtEnd()
		    listNode.AddArgument(ParseExpression())
		    If CurrentToken().Type = TokenType.TYPE_COMMA Then
		      Advance()
		    End If
		  Wend

		  Call Expect(TokenType.TYPE_RBRACKET)

		  Return listNode
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function CurrentToken() As JinjaX.Token
		  If mPosition < mTokens.Count Then
		    Return mTokens(mPosition)
		  End If
		  Return mTokens(mTokens.Count - 1) // Return last token (EOF)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub Advance()
		  If mPosition < mTokens.Count - 1 Then
		    mPosition = mPosition + 1
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function IsAtEnd() As Boolean
		  Return CurrentToken().Type = TokenType.TYPE_EOF
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function Expect(expectedType As Double) As JinjaX.Token
		  Var token As JinjaX.Token = CurrentToken()
		  If token.Type <> expectedType Then
		    Raise New JinjaX.TemplateSyntaxException( _
		      "Expected " + TokenType.TokenName(expectedType) + _
		      " but got " + TokenType.TokenName(token.Type) + _
		      " ('" + token.Value + "')")
		  End If
		  Advance()
		  Return token
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ExpectName() As JinjaX.Token
		  Return Expect(TokenType.TYPE_NAME)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub ExpectKeyword(keyword As String)
		  Var token As JinjaX.Token = CurrentToken()
		  If token.Type <> TokenType.TYPE_KEYWORD Or token.Value.Lowercase() <> keyword.Lowercase() Then
		    Raise New JinjaX.TemplateSyntaxException( _
		      "Expected keyword '" + keyword + "' but got '" + token.Value + "'")
		  End If
		  Advance()
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub SkipToBlockEnd()
		  While CurrentToken().Type <> TokenType.TYPE_BLOCK_END And Not IsAtEnd()
		    Advance()
		  Wend
		  If CurrentToken().Type = TokenType.TYPE_BLOCK_END Then
		    Advance()
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function PeekBlockKeyword() As String
		  // Look ahead: if current is BLOCK_BEGIN, peek at next token for keyword
		  If CurrentToken().Type = TokenType.TYPE_BLOCK_BEGIN Then
		    If mPosition + 1 < mTokens.Count Then
		      Var nextToken As JinjaX.Token = mTokens(mPosition + 1)
		      If nextToken.Type = TokenType.TYPE_KEYWORD Then
		        Return nextToken.Value.Lowercase()
		      End If
		    End If
		  End If
		  Return ""
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function IsBlockKeyword(keyword As String) As Boolean
		  // Check if current token sequence is {% keyword %}
		  If CurrentToken().Type = TokenType.TYPE_BLOCK_BEGIN Then
		    If mPosition + 1 < mTokens.Count Then
		      Var nextToken As JinjaX.Token = mTokens(mPosition + 1)
		      If nextToken.Type = TokenType.TYPE_KEYWORD And nextToken.Value.Lowercase() = keyword.Lowercase() Then
		        Return True
		      End If
		    End If
		  End If
		  Return False
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function IsEndKeyword(keyword As String) As Boolean
		  // Same as IsBlockKeyword but also checks without BLOCK_BEGIN
		  // for when we're inside a block and the body parser has consumed the begin token
		  If CurrentToken().Type = TokenType.TYPE_BLOCK_BEGIN Then
		    Return IsBlockKeyword(keyword)
		  ElseIf CurrentToken().Type = TokenType.TYPE_KEYWORD And CurrentToken().Value.Lowercase() = keyword.Lowercase() Then
		    Return True
		  End If
		  Return False
		End Function
	#tag EndMethod


	#tag Property, Flags = &h21
		Private mTokens() As JinjaX.Token
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mPosition As Integer
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

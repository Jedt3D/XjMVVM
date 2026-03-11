#tag Class
Protected Class JinjaLexer
	#tag Method, Flags = &h0
		Sub Constructor()
		  // Initialize keyword lookup dictionary (cached for performance)
		  mKeywords = New Dictionary
		  mKeywords.Value("if") = True
		  mKeywords.Value("elif") = True
		  mKeywords.Value("else") = True
		  mKeywords.Value("endif") = True
		  mKeywords.Value("for") = True
		  mKeywords.Value("endfor") = True
		  mKeywords.Value("in") = True
		  mKeywords.Value("extends") = True
		  mKeywords.Value("block") = True
		  mKeywords.Value("endblock") = True
		  mKeywords.Value("include") = True
		  mKeywords.Value("set") = True
		  mKeywords.Value("macro") = True
		  mKeywords.Value("endmacro") = True
		  mKeywords.Value("call") = True
		  mKeywords.Value("endcall") = True
		  mKeywords.Value("with") = True
		  mKeywords.Value("endwith") = True
		  mKeywords.Value("and") = True
		  mKeywords.Value("or") = True
		  mKeywords.Value("not") = True
		  mKeywords.Value("is") = True
		  mKeywords.Value("true") = True
		  mKeywords.Value("false") = True
		  mKeywords.Value("none") = True
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Tokenize(input As String) As Token()
		  mInput = input
		  mPosition = 0
		  mLineNumber = 1
		  mColumnNumber = 1
		  mInBlock = False
		  mBlockType = 0

		  Var tokens() As Token
		  mTokens = tokens

		  While mPosition < mInput.Length
		    If Not mInBlock Then
		      ScanOutsideBlock()
		    Else
		      ScanInsideBlock()
		    End If
		  Wend

		  // Emit any remaining data
		  EmitDataToken()

		  // Add EOF token
		  mTokens.Add(New Token(TokenType.TYPE_EOF, "", mLineNumber, mColumnNumber))

		  Return mTokens
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub ScanOutsideBlock()
		  // Check for delimiter starts at current position
		  If StartsWithDelimiter(mVariableStart) Then
		    EmitDataToken()
		    mPosition = mPosition + mVariableStart.Length
		    UpdateLineColumnForString(mVariableStart)
		    mInBlock = True
		    mBlockType = 1 // variable
		    mTokens.Add(New Token(TokenType.TYPE_VARIABLE_BEGIN, mVariableStart, mLineNumber, mColumnNumber))
		    Return
		  End If

		  If StartsWithDelimiter(mBlockStart) Then
		    EmitDataToken()
		    mPosition = mPosition + mBlockStart.Length
		    UpdateLineColumnForString(mBlockStart)
		    mInBlock = True
		    mBlockType = 2 // block
		    mTokens.Add(New Token(TokenType.TYPE_BLOCK_BEGIN, mBlockStart, mLineNumber, mColumnNumber))
		    Return
		  End If

		  If StartsWithDelimiter(mCommentStart) Then
		    EmitDataToken()
		    mPosition = mPosition + mCommentStart.Length
		    UpdateLineColumnForString(mCommentStart)
		    SkipComment()
		    Return
		  End If

		  // Regular character — accumulate into data buffer
		  Var ch As String = mInput.Mid(mPosition + 1, 1)
		  mDataBuffer.Add(ch)
		  mPosition = mPosition + 1
		  UpdateLineColumn(ch)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub EmitDataToken()
		  If mDataBuffer.Count > 0 Then
		    Var data As String = String.FromArray(mDataBuffer, "")
		    mTokens.Add(New Token(TokenType.TYPE_DATA, data, mLineNumber, mColumnNumber))
		    Var empty() As String
		    mDataBuffer = empty
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub ScanInsideBlock()
		  SkipWhitespace()

		  // Check if we've reached the end of current block
		  If mBlockType = 1 Then // Variable block
		    If StartsWithDelimiter(mVariableEnd) Then
		      mPosition = mPosition + mVariableEnd.Length
		      UpdateLineColumnForString(mVariableEnd)
		      mTokens.Add(New Token(TokenType.TYPE_VARIABLE_END, mVariableEnd, mLineNumber, mColumnNumber))
		      mInBlock = False
		      mBlockType = 0
		      Return
		    End If
		  ElseIf mBlockType = 2 Then // Block statement
		    If StartsWithDelimiter(mBlockEnd) Then
		      mPosition = mPosition + mBlockEnd.Length
		      UpdateLineColumnForString(mBlockEnd)
		      mTokens.Add(New Token(TokenType.TYPE_BLOCK_END, mBlockEnd, mLineNumber, mColumnNumber))
		      mInBlock = False
		      mBlockType = 0
		      Return
		    End If
		  End If

		  // Still inside block — scan next token
		  If mPosition < mInput.Length Then
		    ScanToken()
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub ScanToken()
		  Var ch As String = CurrentChar()
		  Var nextCh As String = PeekChar(1)

		  Select Case ch
		  Case "("
		    mTokens.Add(New Token(TokenType.TYPE_LPAREN, "(", mLineNumber, mColumnNumber))
		    mPosition = mPosition + 1
		    UpdateLineColumn(ch)
		    Return
		  Case ")"
		    mTokens.Add(New Token(TokenType.TYPE_RPAREN, ")", mLineNumber, mColumnNumber))
		    mPosition = mPosition + 1
		    UpdateLineColumn(ch)
		    Return
		  Case "["
		    mTokens.Add(New Token(TokenType.TYPE_LBRACKET, "[", mLineNumber, mColumnNumber))
		    mPosition = mPosition + 1
		    UpdateLineColumn(ch)
		    Return
		  Case "]"
		    mTokens.Add(New Token(TokenType.TYPE_RBRACKET, "]", mLineNumber, mColumnNumber))
		    mPosition = mPosition + 1
		    UpdateLineColumn(ch)
		    Return
		  Case ","
		    mTokens.Add(New Token(TokenType.TYPE_COMMA, ",", mLineNumber, mColumnNumber))
		    mPosition = mPosition + 1
		    UpdateLineColumn(ch)
		    Return
		  Case ":"
		    mTokens.Add(New Token(TokenType.TYPE_COLON, ":", mLineNumber, mColumnNumber))
		    mPosition = mPosition + 1
		    UpdateLineColumn(ch)
		    Return
		  Case "|"
		    mTokens.Add(New Token(TokenType.TYPE_PIPE, "|", mLineNumber, mColumnNumber))
		    mPosition = mPosition + 1
		    UpdateLineColumn(ch)
		    Return
		  Case "."
		    mTokens.Add(New Token(TokenType.TYPE_DOT, ".", mLineNumber, mColumnNumber))
		    mPosition = mPosition + 1
		    UpdateLineColumn(ch)
		    Return
		  Case "="
		    If nextCh = "=" Then
		      mTokens.Add(New Token(TokenType.TYPE_OPERATOR, "==", mLineNumber, mColumnNumber))
		      mPosition = mPosition + 2
		      UpdateLineColumn(ch)
		      UpdateLineColumn(nextCh)
		    Else
		      mTokens.Add(New Token(TokenType.TYPE_ASSIGN, "=", mLineNumber, mColumnNumber))
		      mPosition = mPosition + 1
		      UpdateLineColumn(ch)
		    End If
		    Return
		  Case "!"
		    If nextCh = "=" Then
		      mTokens.Add(New Token(TokenType.TYPE_OPERATOR, "!=", mLineNumber, mColumnNumber))
		      mPosition = mPosition + 2
		      UpdateLineColumn(ch)
		      UpdateLineColumn(nextCh)
		    Else
		      mTokens.Add(New Token(TokenType.TYPE_OPERATOR, "!", mLineNumber, mColumnNumber))
		      mPosition = mPosition + 1
		      UpdateLineColumn(ch)
		    End If
		    Return
		  Case "<"
		    If nextCh = "=" Then
		      mTokens.Add(New Token(TokenType.TYPE_OPERATOR, "<=", mLineNumber, mColumnNumber))
		      mPosition = mPosition + 2
		      UpdateLineColumn(ch)
		      UpdateLineColumn(nextCh)
		    Else
		      mTokens.Add(New Token(TokenType.TYPE_OPERATOR, "<", mLineNumber, mColumnNumber))
		      mPosition = mPosition + 1
		      UpdateLineColumn(ch)
		    End If
		    Return
		  Case ">"
		    If nextCh = "=" Then
		      mTokens.Add(New Token(TokenType.TYPE_OPERATOR, ">=", mLineNumber, mColumnNumber))
		      mPosition = mPosition + 2
		      UpdateLineColumn(ch)
		      UpdateLineColumn(nextCh)
		    Else
		      mTokens.Add(New Token(TokenType.TYPE_OPERATOR, ">", mLineNumber, mColumnNumber))
		      mPosition = mPosition + 1
		      UpdateLineColumn(ch)
		    End If
		    Return
		  Case "+"
		    mTokens.Add(New Token(TokenType.TYPE_OPERATOR, "+", mLineNumber, mColumnNumber))
		    mPosition = mPosition + 1
		    UpdateLineColumn(ch)
		    Return
		  Case "-"
		    mTokens.Add(New Token(TokenType.TYPE_OPERATOR, "-", mLineNumber, mColumnNumber))
		    mPosition = mPosition + 1
		    UpdateLineColumn(ch)
		    Return
		  Case "*"
		    If nextCh = "*" Then
		      mTokens.Add(New Token(TokenType.TYPE_OPERATOR, "**", mLineNumber, mColumnNumber))
		      mPosition = mPosition + 2
		      UpdateLineColumn(ch)
		      UpdateLineColumn(nextCh)
		    Else
		      mTokens.Add(New Token(TokenType.TYPE_OPERATOR, "*", mLineNumber, mColumnNumber))
		      mPosition = mPosition + 1
		      UpdateLineColumn(ch)
		    End If
		    Return
		  Case "/"
		    If nextCh = "/" Then
		      mTokens.Add(New Token(TokenType.TYPE_OPERATOR, "//", mLineNumber, mColumnNumber))
		      mPosition = mPosition + 2
		      UpdateLineColumn(ch)
		      UpdateLineColumn(nextCh)
		    Else
		      mTokens.Add(New Token(TokenType.TYPE_OPERATOR, "/", mLineNumber, mColumnNumber))
		      mPosition = mPosition + 1
		      UpdateLineColumn(ch)
		    End If
		    Return
		  Case "%"
		    mTokens.Add(New Token(TokenType.TYPE_OPERATOR, "%", mLineNumber, mColumnNumber))
		    mPosition = mPosition + 1
		    UpdateLineColumn(ch)
		    Return
		  Case "~"
		    mTokens.Add(New Token(TokenType.TYPE_OPERATOR, "~", mLineNumber, mColumnNumber))
		    mPosition = mPosition + 1
		    UpdateLineColumn(ch)
		    Return
		  End Select

		  // String literals
		  If ch = Chr(34) Then // double quote
		    ScanStringLiteral(Chr(34))
		    Return
		  End If

		  If ch = "'" Then // single quote
		    ScanStringLiteral("'")
		    Return
		  End If

		  // Numbers
		  If IsDigit(ch) Then
		    ScanNumber()
		    Return
		  End If

		  // Identifiers and keywords
		  If IsIdentifierStart(ch) Then
		    ScanIdentifier()
		    Return
		  End If

		  // Unknown character — skip
		  mPosition = mPosition + 1
		  UpdateLineColumn(ch)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub ScanStringLiteral(quoteChar As String)
		  Var startLine As Integer = mLineNumber
		  Var startCol As Integer = mColumnNumber
		  Var parts() As String

		  // Skip opening quote
		  mPosition = mPosition + 1
		  UpdateLineColumn(quoteChar)

		  While mPosition < mInput.Length
		    Var ch As String = mInput.Mid(mPosition + 1, 1)

		    // Handle escape sequences
		    If ch = "\" Then
		      If mPosition + 1 < mInput.Length Then
		        Var escapedChar As String = mInput.Mid(mPosition + 2, 1)
		        Select Case escapedChar
		        Case "n"
		          parts.Add(Chr(10))
		        Case "t"
		          parts.Add(Chr(9))
		        Case "\"
		          parts.Add("\")
		        Case "'"
		          parts.Add("'")
		        Case Chr(34)
		          parts.Add(Chr(34))
		        Else
		          parts.Add("\" + escapedChar)
		        End Select
		        mPosition = mPosition + 2
		        UpdateLineColumn(ch)
		        UpdateLineColumn(escapedChar)
		        Continue
		      End If
		    End If

		    // End of string
		    If ch = quoteChar Then
		      Var strVal As String = String.FromArray(parts, "")
		      mTokens.Add(New Token(TokenType.TYPE_STRING, strVal, startLine, startCol))
		      mPosition = mPosition + 1
		      UpdateLineColumn(ch)
		      Return
		    End If

		    parts.Add(ch)
		    mPosition = mPosition + 1
		    UpdateLineColumn(ch)
		  Wend

		  // Unterminated string
		  Raise New TemplateSyntaxException("Unterminated string literal", "", startLine)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub ScanNumber()
		  Var startPos As Integer = mPosition
		  Var isFloat As Boolean = False

		  While mPosition < mInput.Length
		    Var ch As String = mInput.Mid(mPosition + 1, 1)

		    If IsDigit(ch) Then
		      mPosition = mPosition + 1
		      UpdateLineColumn(ch)
		    ElseIf ch = "." And Not isFloat Then
		      // Check that next char is also a digit (not a method call like 42.ToString)
		      If mPosition + 1 < mInput.Length And IsDigit(mInput.Mid(mPosition + 2, 1)) Then
		        isFloat = True
		        mPosition = mPosition + 1
		        UpdateLineColumn(ch)
		      Else
		        Exit
		      End If
		    Else
		      Exit
		    End If
		  Wend

		  Var numStr As String = mInput.Mid(startPos + 1, mPosition - startPos)
		  If isFloat Then
		    mTokens.Add(New Token(TokenType.TYPE_FLOAT, numStr, mLineNumber, mColumnNumber))
		  Else
		    mTokens.Add(New Token(TokenType.TYPE_INTEGER, numStr, mLineNumber, mColumnNumber))
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub ScanIdentifier()
		  Var startPos As Integer = mPosition

		  While mPosition < mInput.Length
		    Var ch As String = mInput.Mid(mPosition + 1, 1)
		    If IsIdentifierChar(ch) Then
		      mPosition = mPosition + 1
		      UpdateLineColumn(ch)
		    Else
		      Exit
		    End If
		  Wend

		  Var identifier As String = mInput.Mid(startPos + 1, mPosition - startPos)

		  // Check if it's a keyword
		  If mKeywords.HasKey(identifier.Lowercase) Then
		    mTokens.Add(New Token(TokenType.TYPE_KEYWORD, identifier, mLineNumber, mColumnNumber))
		  Else
		    mTokens.Add(New Token(TokenType.TYPE_NAME, identifier, mLineNumber, mColumnNumber))
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub SkipComment()
		  // Skip everything until we find the comment end delimiter #}
		  While mPosition < mInput.Length
		    If StartsWithDelimiter(mCommentEnd) Then
		      mPosition = mPosition + mCommentEnd.Length
		      UpdateLineColumnForString(mCommentEnd)
		      Return
		    End If

		    Var ch As String = mInput.Mid(mPosition + 1, 1)
		    mPosition = mPosition + 1
		    UpdateLineColumn(ch)
		  Wend

		  // Unterminated comment
		  Raise New TemplateSyntaxException("Unterminated comment", "", mLineNumber)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub SkipWhitespace()
		  While mPosition < mInput.Length
		    Var ch As String = mInput.Mid(mPosition + 1, 1)
		    If IsWhitespace(ch) Then
		      mPosition = mPosition + 1
		      UpdateLineColumn(ch)
		    Else
		      Exit
		    End If
		  Wend
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function StartsWithDelimiter(delimiter As String) As Boolean
		  If mPosition + delimiter.Length > mInput.Length Then
		    Return False
		  End If

		  Var substring As String = mInput.Mid(mPosition + 1, delimiter.Length)
		  Return substring = delimiter
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function CurrentChar() As String
		  If mPosition < mInput.Length Then
		    Return mInput.Mid(mPosition + 1, 1)
		  End If
		  Return ""
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function PeekChar(offset As Integer) As String
		  If mPosition + offset < mInput.Length Then
		    Return mInput.Mid(mPosition + offset + 1, 1)
		  End If
		  Return ""
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function IsWhitespace(ch As String) As Boolean
		  Return ch = " " Or ch = Chr(9) Or ch = Chr(10) Or ch = Chr(13)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function IsDigit(ch As String) As Boolean
		  Return ch >= "0" And ch <= "9"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function IsIdentifierStart(ch As String) As Boolean
		  Return (ch >= "a" And ch <= "z") Or (ch >= "A" And ch <= "Z") Or ch = "_"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function IsIdentifierChar(ch As String) As Boolean
		  Return IsIdentifierStart(ch) Or IsDigit(ch)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub UpdateLineColumn(ch As String)
		  If ch = Chr(10) Then
		    mLineNumber = mLineNumber + 1
		    mColumnNumber = 1
		  Else
		    mColumnNumber = mColumnNumber + 1
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub UpdateLineColumnForString(s As String)
		  Var i As Integer
		  For i = 1 To s.Length
		    UpdateLineColumn(s.Mid(i, 1))
		  Next
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h21
		Private mInput As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mPosition As Integer = 0
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mLineNumber As Integer = 1
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mColumnNumber As Integer = 1
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mTokens() As Token
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mDataBuffer() As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mInBlock As Boolean = False
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mBlockType As Integer = 0
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mKeywords As Dictionary
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mBlockStart As String = "{%"
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mBlockEnd As String = "%}"
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mVariableStart As String = "{{"
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mVariableEnd As String = "}}"
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mCommentStart As String = "{#"
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mCommentEnd As String = "#}"
	#tag EndProperty

End Class
#tag EndClass

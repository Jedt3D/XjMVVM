#tag Module
Protected Module MarkupSafe
	#tag Method, Flags = &h0
		Function Escape(value As Variant) As MarkupString
		  If value.Type = Variant.TypeNil Then
		    Return New MarkupString("")
		  End If
		  
		  If value IsA MarkupString Then
		    Return MarkupString(value)
		  End If
		  
		  Var Str As String = SoftStr(value)
		  Return New MarkupString(EscapeString(Str))
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function EscapeString(s As String) As String
		  If s.Length = 0 Then Return ""
		  
		  Var parts() As String
		  Var start As Integer = 1
		  Var i As Integer = 1
		  Var sLen As Integer = s.Length
		  
		  While i <= sLen
		    Var ch As String = s.Mid(i, 1)
		    Var replacement As String = ""
		    
		    Select Case ch
		    Case "&"
		      replacement = "&amp;"
		    Case "<"
		      replacement = "&lt;"
		    Case ">"
		      replacement = "&gt;"
		    Case Chr(34)
		      replacement = "&quot;"
		    Case "'"
		      replacement = "&#39;"
		    End Select
		    
		    If replacement <> "" Then
		      If i > start Then
		        parts.Add(s.Mid(start, i - start))
		      End If
		      parts.Add(replacement)
		      start = i + 1
		    End If
		    
		    i = i + 1
		  Wend
		  
		  If start <= sLen Then
		    parts.Add(s.Mid(start, sLen - start + 1))
		  End If
		  
		  If parts.Count = 0 Then Return s
		  
		  Return String.FromArray(parts, "")
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Join(separator As MarkupString, items() As Variant) As MarkupString
		  Var parts() As String
		  For Each item As Variant In items
		    parts.Add(Escape(item).ToString())
		  Next
		  Return New MarkupString(String.FromArray(parts, separator.ToString()))
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function SoftStr(value As Variant) As String
		  If value.Type = Variant.TypeNil Then Return ""
		  
		  If value IsA MarkupString Then
		    Return MarkupString(value).ToString()
		  End If
		  
		  Try
		    Return value.StringValue
		  Catch
		    Return ""
		  End Try
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function UnescapeString(s As String) As String
		  If s.Length = 0 Then Return ""
		  Var result As String = s
		  result = result.ReplaceAll("&lt;", "<")
		  result = result.ReplaceAll("&gt;", ">")
		  result = result.ReplaceAll("&quot;", Chr(34))
		  result = result.ReplaceAll("&#34;", Chr(34))
		  result = result.ReplaceAll("&#39;", "'")
		  result = result.ReplaceAll("&amp;", "&")
		  Return result
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
End Module
#tag EndModule

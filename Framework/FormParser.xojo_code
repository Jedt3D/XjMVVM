#tag Module
Protected Module FormParser
	#tag Method, Flags = &h0, Description = "Parses a URL-encoded form body (key=val&key2=val2) into a Dictionary."
		Function Parse(body As String) As Dictionary
		  Var result As New Dictionary()

		  If body.Length = 0 Then Return result

		  Var pairs() As String = body.Split("&")
		  For i As Integer = 0 To pairs.Count - 1
		    Var pair As String = pairs(i)
		    Var eqPos As Integer = pair.IndexOf("=")

		    If eqPos >= 0 Then
		      Var key As String = DecodeURIComponent(pair.Left(eqPos))
		      Var value As String = DecodeURIComponent(pair.Mid(eqPos + 1))
		      result.Value(key) = value
		    ElseIf pair.Length > 0 Then
		      result.Value(DecodeURIComponent(pair)) = ""
		    End If
		  Next

		  Return result
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Decodes a URL-encoded string (percent-encoding and + for space)."
		Function DecodeURIComponent(encoded As String) As String
		  // Replace + with space first
		  Var s As String = encoded.ReplaceAll("+", " ")

		  // Decode percent-encoded characters
		  Var result As String = ""
		  Var i As Integer = 0
		  While i < s.Length
		    Var ch As String = s.Mid(i, 1)
		    If ch = "%" And i + 2 < s.Length Then
		      Var hex As String = s.Mid(i + 1, 2)
		      Try
		        Var code As Integer = Integer.FromHex(hex)
		        result = result + Chr(code)
		        i = i + 3
		      Catch
		        result = result + ch
		        i = i + 1
		      End Try
		    Else
		      result = result + ch
		      i = i + 1
		    End If
		  Wend

		  Return result
		End Function
	#tag EndMethod

End Module
#tag EndModule

#tag Module
Protected Module JSONSerializer
	#tag Method, Flags = &h0, Description = "Escapes a string value for use inside a JSON string literal."
		Function EscapeString(s As String) As String
		  s = s.ReplaceAll("\", "\\")
		  s = s.ReplaceAll(Chr(34), "\""")
		  s = s.ReplaceAll(Chr(10), "\n")
		  s = s.ReplaceAll(Chr(13), "\r")
		  s = s.ReplaceAll(Chr(9), "\t")
		  Return s
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Serializes a Dictionary of string values to a JSON object string."
		Function DictToJSON(d As Dictionary) As String
		  Var parts() As String
		  For Each key As Variant In d.Keys
		    Var k As String = EscapeString(key.StringValue)
		    Var v As String = EscapeString(d.Value(key).StringValue)
		    parts.Add("""" + k + """" + ":" + """" + v + """")
		  Next
		  Return "{" + String.FromArray(parts, ",") + "}"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Serializes a Variant() of Dictionary to a JSON array string."
		Function ArrayToJSON(items() As Variant) As String
		  Var parts() As String
		  For Each item As Variant In items
		    Var d As Dictionary = item
		    parts.Add(DictToJSON(d))
		  Next
		  Return "[" + String.FromArray(parts, ",") + "]"
		End Function
	#tag EndMethod

End Module
#tag EndModule

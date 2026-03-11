#tag Module
Protected Module QueryParser
	#tag Method, Flags = &h0, Description = "Parses a query string into a Dictionary. Handles the leading '?' if present."
		Function Parse(queryString As String) As Dictionary
		  Var qs As String = queryString

		  // Strip leading ? if present
		  If qs.Left(1) = "?" Then
		    qs = qs.Mid(1)
		  End If

		  // Reuse FormParser since query strings use the same encoding
		  Return FormParser.Parse(qs)
		End Function
	#tag EndMethod

End Module
#tag EndModule

#tag Class
Protected Class BaseViewModel
	#tag Method, Flags = &h0, Description = 000E000A0A000E0F00000E0000000F000B0D00
		Function GetFormValue(key As String) As String
		  If mFormData = Nil Then
		    mFormData = FormParser.Parse(mRawBody)
		  End If
		  
		  If mFormData.HasKey(key) Then
		    Return mFormData.Value(key).StringValue
		  End If
		  
		  Return ""
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 000E000A0A0A0E0E000F00000A000A0A000F00
		Function GetParam(key As String) As String
		  // Check path params first
		  If PathParams <> Nil And PathParams.HasKey(key) Then
		    Return PathParams.Value(key).StringValue
		  End If
		  
		  // Fall back to query string
		  Var qs As Dictionary = QueryParser.Parse(Request.QueryString)
		  If qs.HasKey(key) Then
		    Return qs.Value(key).StringValue
		  End If
		  
		  Return ""
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 0D000A0C0E000000000E00000000000B0AED0000000E0000000E000D
		Sub Handle()
		  // Cache POST body immediately — Request.Body may only be readable once
		  If Request.Method = "POST" Then
		    mRawBody = Request.Body
		  End If

		  Select Case Request.Method
		  Case "GET"
		    OnGet()
		  Case "POST"
		    OnPost()
		  Else
		    Response.Status = 405
		    Response.Write("Method Not Allowed")
		  End Select
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 000E000D0E00000B0C0A0000000A0D0E0E000E000E0000
		Sub OnGet()
		  Response.Status = 405
		  Response.Write("Method Not Allowed")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 000E000D0E00000B0C0A0000000A0D0E0000000E0E0000
		Sub OnPost()
		  Response.Status = 405
		  Response.Write("Method Not Allowed")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 000E0D0A00ED00EC000E00000E00
		Sub Redirect(url As String, statusCode As Integer = 302)
		  Response.Status = statusCode
		  Response.Header("Location") = url
		  Response.Header("Content-Type") = "text/html; charset=utf-8"
		  Response.Write("<html><head><meta http-equiv=""refresh"" content=""0;url=" + url + """></head><body>Redirecting to <a href=""" + url + """>" + url + "</a></body></html>")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 000EEFBFBD0A00000A000E000A0E000000000E000E000C000E000D0C000A000A0D00000E0000000000000E0E00000E00
		Sub Render(templateName As String, context As Dictionary)
		  // Auto-inject flash message if available
		  Var ws As WebSession = Self.Session
		  If ws IsA Session Then
		    Var sess As Session = Session(ws)
		    Var flash As Dictionary = sess.GetFlash()
		    If flash <> Nil Then
		      context.Value("flash") = flash
		    End If
		  End If
		  
		  // Auto-inject current user info for nav display
		  Var ws2 As WebSession = Self.Session
		  If ws2 IsA Session Then
		    Var sess2 As Session = Session(ws2)
		    Var userCtx As New Dictionary()
		    userCtx.Value("id") = Str(sess2.CurrentUserID)
		    userCtx.Value("username") = sess2.CurrentUsername
		    userCtx.Value("logged_in") = If(sess2.IsLoggedIn(), "1", "0")
		    context.Value("current_user") = userCtx
		  End If

		  Var tmpl As JinjaX.CompiledTemplate = Jinja.GetTemplate(templateName)
		  Var html As String = tmpl.Render(context)
		  Response.Header("Content-Type") = "text/html; charset=utf-8"
		  Response.Write(html)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 000EDE000A000E00000A0E000E000A0E
		Sub RenderError(statusCode As Integer, message As String)
		  Response.Status = statusCode
		  Var context As New Dictionary()
		  context.Value("status_code") = statusCode
		  context.Value("message") = message
		  
		  Try
		    Render("errors/" + Str(statusCode) + ".html", context)
		  Catch
		    // Fallback if error template doesn't exist
		    Response.Header("Content-Type") = "text/html; charset=utf-8"
		    Response.Write("<h1>" + Str(statusCode) + "</h1><p>" + message + "</p>")
		  End Try
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 000E000A0F0A000E000A0E00000E000E00000F000D00000A0A0F0E00ED00EC00
		Sub SetFlash(message As String, type As String = "success")
		  Var ws As WebSession = Self.Session
		  If ws IsA Session Then
		    Var sess As Session = Session(ws)
		    sess.SetFlash(message, type)
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Redirects to /login if not logged in. Returns True if redirect was issued."
		Function RequireLogin() As Boolean
		  Var ws As WebSession = Self.Session
		  If ws IsA Session Then
		    Var sess As Session = Session(ws)
		    If Not sess.IsLoggedIn() Then
		      SetFlash("Please log in to continue", "info")
		      Redirect("/login")
		      Return True
		    End If
		  End If
		  Return False
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Returns the current user ID from the session, or 0 if not logged in."
		Function CurrentUserID() As Integer
		  Var ws As WebSession = Self.Session
		  If ws IsA Session Then
		    Return Session(ws).CurrentUserID
		  End If
		  Return 0
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Returns the current username from the session, or empty string."
		Function CurrentUsername() As String
		  Var ws As WebSession = Self.Session
		  If ws IsA Session Then
		    Return Session(ws).CurrentUsername
		  End If
		  Return ""
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 00000E000A00000000000000000E000E00000E
		Sub WriteJSON(jsonString As String)
		  Response.Header("Content-Type") = "application/json; charset=utf-8"
		  Response.Write(jsonString)
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0
		Jinja As JinjaX.JinjaEnvironment
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mFormData As Dictionary
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mRawBody As String
	#tag EndProperty

	#tag Property, Flags = &h0
		PathParams As Dictionary
	#tag EndProperty

	#tag Property, Flags = &h0
		Request As WebRequest
	#tag EndProperty

	#tag Property, Flags = &h0
		Response As WebResponse
	#tag EndProperty

	#tag Property, Flags = &h0
		Session As WebSession
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

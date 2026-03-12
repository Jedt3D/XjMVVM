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
		  // Auto-inject flash message (always set to prevent UndefinedVariableException)
		  context.Value("flash") = ""
		  Var ws As WebSession = Self.Session
		  If ws IsA Session Then
		    Var sess As Session = Session(ws)
		    Var flash As Dictionary = sess.GetFlash()
		    If flash <> Nil Then
		      context.Value("flash") = flash
		    End If
		  End If

		  // Auto-inject current user info for nav display (always add to prevent UndefinedVariableException)
		  Var userCtx As New Dictionary()
		  userCtx.Value("id") = Str(CurrentUserID())
		  userCtx.Value("username") = CurrentUsername()
		  userCtx.Value("logged_in") = If(CurrentUserID() > 0, "1", "0")
		  context.Value("current_user") = userCtx

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

	#tag Method, Flags = &h0, Description = "Redirects to /login if not logged in. Saves current path in ?next= for post-login redirect. Returns True if redirect was issued."
		Function RequireLogin() As Boolean
		  If CurrentUserID() > 0 Then Return False
		  // Build the original URL the user was trying to reach
		  Var p As String = Request.Path
		  If p.Left(1) <> "/" Then p = "/" + p
		  Redirect("/login?next=" + EncodeURLComponent(p))
		  Return True
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Returns the current user ID from the auth cookie, or 0 if not authenticated."
		Function CurrentUserID() As Integer
		  Var auth As Dictionary = ParseAuthCookie()
		  If auth <> Nil Then Return auth.Value("user_id").IntegerValue
		  Return 0
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Returns the current username from the auth cookie, or empty string."
		Function CurrentUsername() As String
		  Var auth As Dictionary = ParseAuthCookie()
		  If auth <> Nil Then Return auth.Value("username").StringValue
		  Return ""
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Returns 401 JSON if not logged in. Returns True if response was sent."
		Function RequireLoginJSON() As Boolean
		  If CurrentUserID() > 0 Then Return False
		  Response.Status = 401
		  WriteJSON("{""error"":""Authentication required""}")
		  Return True
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 00000E000A00000000000000000E000E00000E
		Sub WriteJSON(jsonString As String)
		  Response.Header("Content-Type") = "application/json; charset=utf-8"
		  Response.Write(jsonString)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Generates the signed auth cookie value for a user."
		Function AuthCookieValue(userID As Integer, username As String) As String
		  Var payload As String = Str(userID) + ":" + username
		  Var hmac As String = EncodeHex(Crypto.SHA256(payload + ":" + App.mAuthSecret))
		  Return payload + ":" + hmac
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Sets auth cookie via HTTP header + JS for localStorage, then redirects. Use after login/signup."
		Sub RedirectWithAuth(url As String, userID As Integer, username As String)
		  Var cookieVal As String = AuthCookieValue(userID, username)
		  // Set auth cookie via HTTP header (proven to work in HandleURL)
		  Response.Header("Set-Cookie") = "mvvm_auth=" + cookieVal + "; Path=/; SameSite=Lax"
		  // JS intermediate page sets localStorage (for nav display) and redirects
		  Response.Header("Content-Type") = "text/html; charset=utf-8"
		  Response.Write("<html><head><script>" + _
		  "localStorage.setItem('_auth_user','" + username + "');" + _
		  "sessionStorage.setItem('_flash_msg','Welcome, " + username + "!');" + _
		  "sessionStorage.setItem('_flash_type','success');" + _
		  "window.location.href='" + url + "';" + _
		  "</script></head><body>Redirecting...</body></html>")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Clears auth cookie via HTTP header + JS for localStorage, then redirects. Use for logout."
		Sub RedirectWithLogout(url As String)
		  // Clear auth cookie via HTTP header
		  Response.Header("Set-Cookie") = "mvvm_auth=; Path=/; Max-Age=0; SameSite=Lax"
		  // JS intermediate page clears localStorage and redirects
		  Response.Header("Content-Type") = "text/html; charset=utf-8"
		  Response.Write("<html><head><script>" + _
		  "localStorage.removeItem('_auth_user');" + _
		  "window.location.href='" + url + "';" + _
		  "</script></head><body>Redirecting...</body></html>")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21, Description = "Reads and verifies the auth cookie. Returns Dictionary with user_id/username or Nil."
		Private Function ParseAuthCookie() As Dictionary
		  // Return cached result if already parsed this request
		  If mAuthParsed Then Return mAuthCache
		  mAuthParsed = True

		  Var cookieHeader As String = Request.Header("Cookie")
		  If cookieHeader.Length = 0 Then Return Nil

		  // Find mvvm_auth=... in cookie string
		  Var cookies() As String = cookieHeader.Split("; ")
		  Var authValue As String = ""
		  For Each c As String In cookies
		    c = c.Trim()
		    If c.Left(10) = "mvvm_auth=" Then
		      authValue = c.Middle(10)
		      Exit
		    End If
		  Next
		  If authValue.Length = 0 Then Return Nil

		  // Format: userID:username:hmac (hmac is 64-char hex SHA-256)
		  // Find the hmac by locating the last colon
		  If authValue.Length < 66 Then Return Nil

		  Var lastColonPos As Integer = authValue.Length - 65
		  If authValue.Middle(lastColonPos, 1) <> ":" Then Return Nil

		  Var payload As String = authValue.Left(lastColonPos)
		  Var hmac As String = authValue.Middle(lastColonPos + 1)

		  // Verify HMAC
		  Var expected As String = EncodeHex(Crypto.SHA256(payload + ":" + App.mAuthSecret))
		  If hmac <> expected Then Return Nil

		  // Parse payload: userID:username
		  Var colonPos As Integer = payload.IndexOf(":")
		  If colonPos < 1 Then Return Nil

		  Var uid As Integer = Val(payload.Left(colonPos))
		  Var uname As String = payload.Middle(colonPos + 1)
		  If uid <= 0 Then Return Nil

		  Var result As New Dictionary()
		  result.Value("user_id") = uid
		  result.Value("username") = uname
		  mAuthCache = result
		  Return result
		End Function
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

	#tag Property, Flags = &h21
		Private mAuthParsed As Boolean
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mAuthCache As Dictionary
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

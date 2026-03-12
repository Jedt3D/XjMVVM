#tag Class
Protected Class LoginVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnGet()
		  // If already logged in, redirect to home
		  If CurrentUserID() > 0 Then
		    Redirect("/notes")
		    Return
		  End If

		  Var context As New Dictionary()
		  context.Value("page_title") = "Log In"
		  context.Value("error_message") = ""
		  // Pass next URL to template so the form can include it
		  context.Value("next_url") = GetParam("next")
		  Render("auth/login.html", context)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub OnPost()
		  Var username As String = GetFormValue("username").Trim()
		  Var password As String = GetFormValue("password")

		  // Determine where to go after login
		  Var nextURL As String = GetFormValue("next")
		  If nextURL.Length = 0 Then nextURL = GetParam("next")
		  If nextURL.Length = 0 Then nextURL = "/notes"

		  If username.Length = 0 Or password.Length = 0 Then
		    RenderLoginWithError("Username and password are required", nextURL)
		    Return
		  End If

		  Var model As New UserModel()
		  If model.VerifyPassword(username, password) Then
		    Var row As Dictionary = model.FindByUsername(username)
		    Var uid As Integer = Val(row.Value("id").StringValue)
		    RedirectWithAuth(nextURL, uid, username)
		  Else
		    RenderLoginWithError("Invalid username or password", nextURL)
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub RenderLoginWithError(errorMsg As String, nextURL As String)
		  Var context As New Dictionary()
		  context.Value("page_title") = "Log In"
		  context.Value("next_url") = nextURL
		  context.Value("error_message") = errorMsg
		  Render("auth/login.html", context)
		End Sub
	#tag EndMethod

End Class
#tag EndClass

#tag Class
Protected Class SignupVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnGet()
		  If CurrentUserID() > 0 Then
		    Redirect("/notes")
		    Return
		  End If

		  Var context As New Dictionary()
		  context.Value("page_title") = "Sign Up"
		  context.Value("error_message") = ""
		  Render("auth/signup.html", context)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub OnPost()
		  Var username As String = GetFormValue("username").Trim()
		  Var password As String = GetFormValue("password")
		  Var confirm As String = GetFormValue("password_confirm")

		  If username.Length = 0 Then
		    RenderSignupWithError("Username is required")
		    Return
		  End If

		  If username.Length < 3 Then
		    RenderSignupWithError("Username must be at least 3 characters")
		    Return
		  End If

		  // Note: with client-side SHA-256, password arrives as 64-char hex.
		  // This check is a fallback for non-JS clients.
		  If password.Length < 6 Then
		    RenderSignupWithError("Password must be at least 6 characters")
		    Return
		  End If

		  If password <> confirm Then
		    RenderSignupWithError("Passwords do not match")
		    Return
		  End If

		  Var model As New UserModel()
		  Var newID As Integer = model.Create(username, password)
		  If newID = 0 Then
		    RenderSignupWithError("Username already taken")
		    Return
		  End If

		  RedirectWithAuth("/notes", newID, username)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub RenderSignupWithError(errorMsg As String)
		  Var context As New Dictionary()
		  context.Value("page_title") = "Sign Up"
		  context.Value("error_message") = errorMsg
		  Render("auth/signup.html", context)
		End Sub
	#tag EndMethod

End Class
#tag EndClass

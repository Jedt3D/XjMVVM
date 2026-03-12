#tag Class
Protected Class SignupVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnGet()
		  If CurrentUserID() > 0 Then
		    Redirect("/")
		    Return
		  End If

		  Var context As New Dictionary()
		  context.Value("page_title") = "Sign Up"
		  Render("auth/signup.html", context)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub OnPost()
		  Var username As String = GetFormValue("username").Trim()
		  Var password As String = GetFormValue("password")
		  Var confirm As String = GetFormValue("password_confirm")

		  If username.Length = 0 Then
		    SetFlash("Username is required", "error")
		    Redirect("/signup")
		    Return
		  End If

		  If username.Length < 3 Then
		    SetFlash("Username must be at least 3 characters", "error")
		    Redirect("/signup")
		    Return
		  End If

		  If password.Length < 6 Then
		    SetFlash("Password must be at least 6 characters", "error")
		    Redirect("/signup")
		    Return
		  End If

		  If password <> confirm Then
		    SetFlash("Passwords do not match", "error")
		    Redirect("/signup")
		    Return
		  End If

		  Var model As New UserModel()
		  Var newID As Integer = model.Create(username, password)
		  If newID = 0 Then
		    SetFlash("Username already taken", "error")
		    Redirect("/signup")
		    Return
		  End If

		  Var ws As WebSession = Self.Session
		  If ws IsA Session Then
		    Session(ws).LogIn(newID, username)
		  End If
		  SetFlash("Account created! Welcome, " + username + "!")
		  Redirect("/")
		End Sub
	#tag EndMethod

End Class
#tag EndClass

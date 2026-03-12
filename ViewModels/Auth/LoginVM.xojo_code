#tag Class
Protected Class LoginVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnGet()
		  // If already logged in, redirect to home
		  If CurrentUserID() > 0 Then
		    Redirect("/")
		    Return
		  End If

		  Var context As New Dictionary()
		  context.Value("page_title") = "Log In"
		  Render("auth/login.html", context)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub OnPost()
		  Var username As String = GetFormValue("username").Trim()
		  Var password As String = GetFormValue("password")

		  If username.Length = 0 Or password.Length = 0 Then
		    SetFlash("Username and password are required", "error")
		    Redirect("/login")
		    Return
		  End If

		  Var model As New UserModel()
		  If model.VerifyPassword(username, password) Then
		    Var row As Dictionary = model.FindByUsername(username)
		    Var ws As WebSession = Self.Session
		    If ws IsA Session Then
		      Session(ws).LogIn(Val(row.Value("id").StringValue), username)
		    End If
		    SetFlash("Welcome back, " + username + "!")
		    Redirect("/")
		  Else
		    SetFlash("Invalid username or password", "error")
		    Redirect("/login")
		  End If
		End Sub
	#tag EndMethod

End Class
#tag EndClass

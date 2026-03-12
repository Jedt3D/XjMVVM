#tag Class
Protected Class LogoutVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnPost()
		  Var ws As WebSession = Self.Session
		  If ws IsA Session Then
		    Session(ws).LogOut()
		  End If
		  SetFlash("You have been logged out")
		  Redirect("/notes")
		End Sub
	#tag EndMethod

End Class
#tag EndClass

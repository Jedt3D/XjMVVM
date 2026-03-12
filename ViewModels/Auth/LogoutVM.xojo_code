#tag Class
Protected Class LogoutVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnPost()
		  RedirectWithLogout("/login")
		End Sub
	#tag EndMethod

End Class
#tag EndClass

#tag Class
Protected Class TagsDeleteVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnPost()
		  If RequireLogin() Then Return

		  Var id As Integer = Val(GetParam("id"))
		  Var model As New TagModel()
		  model.Delete(id)
		  SetFlash("Tag deleted")
		  Redirect("/tags")
		End Sub
	#tag EndMethod

End Class
#tag EndClass

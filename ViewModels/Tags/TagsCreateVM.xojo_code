#tag Class
Protected Class TagsCreateVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnPost()
		  Var name As String = GetFormValue("name").Trim()

		  If name.Length = 0 Then
		    SetFlash("Name is required", "error")
		    Redirect("/tags/new")
		    Return
		  End If

		  Var model As New TagModel()
		  Call model.Create(name)
		  SetFlash("Tag created")
		  Redirect("/tags")
		End Sub
	#tag EndMethod

End Class
#tag EndClass

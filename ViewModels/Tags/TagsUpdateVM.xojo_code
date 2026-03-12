#tag Class
Protected Class TagsUpdateVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnPost()
		  Var id As Integer = Val(GetParam("id"))
		  Var name As String = GetFormValue("name").Trim()

		  If name.Length = 0 Then
		    SetFlash("Name is required", "error")
		    Redirect("/tags/" + Str(id) + "/edit")
		    Return
		  End If

		  Var model As New TagModel()
		  model.Update(id, name)
		  SetFlash("Tag updated")
		  Redirect("/tags/" + Str(id))
		End Sub
	#tag EndMethod

End Class
#tag EndClass

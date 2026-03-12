#tag Class
Protected Class TagsAPIDetailVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnGet()
		  Var id As Integer = Val(GetParam("id"))
		  Var model As New TagModel()
		  Var tag As Dictionary = model.GetByID(id)

		  If tag = Nil Then
		    Response.Status = 404
		    WriteJSON("{""error"":""Tag not found""}")
		    Return
		  End If

		  WriteJSON(JSONSerializer.DictToJSON(tag))
		End Sub
	#tag EndMethod

End Class
#tag EndClass

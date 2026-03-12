#tag Class
Protected Class TagsAPIListVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnGet()
		  Var model As New TagModel()
		  Var tags() As Variant = model.GetAll()
		  WriteJSON(JSONSerializer.ArrayToJSON(tags))
		End Sub
	#tag EndMethod

End Class
#tag EndClass

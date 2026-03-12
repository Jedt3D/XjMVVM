#tag Class
Protected Class TagsListVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnGet()
		  Var model As New TagModel()
		  Var tags() As Variant = model.GetAll()

		  Var context As New Dictionary()
		  context.Value("page_title") = "Tags"
		  context.Value("tags") = tags
		  Render("tags/list.html", context)
		End Sub
	#tag EndMethod

End Class
#tag EndClass

#tag Class
Protected Class TagsEditVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnGet()
		  If RequireLogin() Then Return

		  Var id As Integer = Val(GetParam("id"))
		  Var model As New TagModel()
		  Var tag As Dictionary = model.GetByID(id)

		  If tag = Nil Then
		    RenderError(404, "Tag not found")
		    Return
		  End If

		  Var context As New Dictionary()
		  context.Value("page_title") = "Edit: " + tag.Value("name").StringValue
		  context.Value("tag") = tag
		  Render("tags/form.html", context)
		End Sub
	#tag EndMethod

End Class
#tag EndClass

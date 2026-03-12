#tag Class
Protected Class TagsNewVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnGet()
		  Var context As New Dictionary()
		  context.Value("page_title") = "New Tag"
		  Render("tags/form.html", context)
		End Sub
	#tag EndMethod

End Class
#tag EndClass

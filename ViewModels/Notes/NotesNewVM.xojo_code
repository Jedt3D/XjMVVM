#tag Class
Protected Class NotesNewVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnGet()
		  Var context As New Dictionary()
		  context.Value("page_title") = "New Note"
		  Render("notes/form.html", context)
		End Sub
	#tag EndMethod

End Class
#tag EndClass

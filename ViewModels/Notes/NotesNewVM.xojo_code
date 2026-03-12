#tag Class
Protected Class NotesNewVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnGet()
		  If RequireLogin() Then Return

		  Var tagModel As New TagModel()
		  Var allTags() As Variant = tagModel.GetAll()
		  // Mark all tags as unselected for new note form
		  For Each item As Variant In allTags
		    Var t As Dictionary = item
		    t.Value("selected") = "0"
		  Next

		  Var context As New Dictionary()
		  context.Value("page_title") = "New Note"
		  context.Value("all_tags") = allTags
		  Render("notes/form.html", context)
		End Sub
	#tag EndMethod

End Class
#tag EndClass

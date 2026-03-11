#tag Class
Protected Class NotesListVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnGet()
		  Var model As New NoteModel()
		  Var notes() As Variant = model.GetAll()

		  Var context As New Dictionary()
		  context.Value("page_title") = "Notes"
		  context.Value("notes") = notes
		  Render("notes/list.html", context)
		End Sub
	#tag EndMethod

End Class
#tag EndClass

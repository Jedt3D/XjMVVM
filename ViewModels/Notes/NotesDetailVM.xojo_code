#tag Class
Protected Class NotesDetailVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnGet()
		  Var id As Integer = Val(GetParam("id"))
		  Var model As New NoteModel()
		  Var note As Dictionary = model.GetByID(id)

		  If note = Nil Then
		    RenderError(404, "Note not found")
		    Return
		  End If

		  Var context As New Dictionary()
		  context.Value("page_title") = note.Value("title").StringValue
		  context.Value("note") = note
		  Render("notes/detail.html", context)
		End Sub
	#tag EndMethod

End Class
#tag EndClass

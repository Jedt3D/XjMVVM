#tag Class
Protected Class NotesDetailVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnGet()
		  If RequireLogin() Then Return

		  Var id As Integer = Val(GetParam("id"))
		  Var uid As Integer = CurrentUserID()
		  Var model As New NoteModel()
		  Var note As Dictionary = model.GetByID(id, uid)

		  If note = Nil Then
		    RenderError(404, "Note not found")
		    Return
		  End If

		  Var noteTags() As Variant = model.GetTagsForNote(id)

		  Var context As New Dictionary()
		  context.Value("page_title") = note.Value("title").StringValue
		  context.Value("note") = note
		  context.Value("note_tags") = noteTags
		  Render("notes/detail.html", context)
		End Sub
	#tag EndMethod

End Class
#tag EndClass

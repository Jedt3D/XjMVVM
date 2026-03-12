#tag Class
Protected Class NotesEditVM
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

		  // Build all_tags list with selected flag for each tag
		  Var tagModel As New TagModel()
		  Var allTags() As Variant = tagModel.GetAll()
		  Var noteTags() As Variant = model.GetTagsForNote(id)

		  // Build a set of selected tag IDs for fast lookup
		  Var selectedSet As New Dictionary()
		  For Each item As Variant In noteTags
		    Var t As Dictionary = item
		    selectedSet.Value(t.Value("id").StringValue) = True
		  Next

		  // Mark each tag as selected or not
		  For Each item As Variant In allTags
		    Var t As Dictionary = item
		    If selectedSet.HasKey(t.Value("id").StringValue) Then
		      t.Value("selected") = "1"
		    Else
		      t.Value("selected") = "0"
		    End If
		  Next

		  Var context As New Dictionary()
		  context.Value("page_title") = "Edit: " + note.Value("title").StringValue
		  context.Value("note") = note
		  context.Value("all_tags") = allTags
		  Render("notes/form.html", context)
		End Sub
	#tag EndMethod

End Class
#tag EndClass

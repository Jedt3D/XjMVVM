#tag Class
Protected Class NotesAPIDetailVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnGet()
		  Var id As Integer = Val(GetParam("id"))
		  Var model As New NoteModel()
		  Var note As Dictionary = model.GetByID(id)

		  If note = Nil Then
		    Response.Status = 404
		    WriteJSON("{""error"":""Note not found""}")
		    Return
		  End If

		  // Attach tags array to the note JSON manually
		  Var tags() As Variant = model.GetTagsForNote(id)
		  Var noteJSON As String = JSONSerializer.DictToJSON(note)
		  // Insert tags before closing brace
		  Var tagsJSON As String = JSONSerializer.ArrayToJSON(tags)
		  noteJSON = noteJSON.Left(noteJSON.Length - 1) + ",""tags"":" + tagsJSON + "}"
		  WriteJSON(noteJSON)
		End Sub
	#tag EndMethod

End Class
#tag EndClass

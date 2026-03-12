#tag Class
Protected Class NotesCreateVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnPost()
		  Var title As String = GetFormValue("title")
		  Var body As String = GetFormValue("body")

		  If title.Length = 0 Then
		    SetFlash("Title is required", "error")
		    Redirect("/notes/new")
		    Return
		  End If

		  Var model As New NoteModel()
		  Var newID As Integer = model.Create(title, body)

		  // Parse comma-joined tag_ids from multi-value checkboxes
		  Var tagIDsRaw As String = GetFormValue("tag_ids")
		  If tagIDsRaw.Length > 0 Then
		    Var tagIDStrs() As String = tagIDsRaw.Split(",")
		    Var tagIDs() As Integer
		    For Each s As String In tagIDStrs
		      Var tid As Integer = Val(s.Trim())
		      If tid > 0 Then tagIDs.Add(tid)
		    Next
		    model.SetTagsForNote(newID, tagIDs)
		  End If

		  SetFlash("Note created")
		  Redirect("/notes")
		End Sub
	#tag EndMethod

End Class
#tag EndClass

#tag Class
Protected Class NotesUpdateVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnPost()
		  If RequireLogin() Then Return

		  Var id As Integer = Val(GetParam("id"))
		  Var title As String = GetFormValue("title")
		  Var body As String = GetFormValue("body")

		  If title.Length = 0 Then
		    SetFlash("Title is required", "error")
		    Redirect("/notes/" + Str(id) + "/edit")
		    Return
		  End If

		  Var uid As Integer = CurrentUserID()
		  Var model As New NoteModel()
		  model.Update(id, title, body, uid)

		  // Parse comma-joined tag_ids from multi-value checkboxes
		  Var tagIDsRaw As String = GetFormValue("tag_ids")
		  Var tagIDs() As Integer
		  If tagIDsRaw.Length > 0 Then
		    Var tagIDStrs() As String = tagIDsRaw.Split(",")
		    For Each s As String In tagIDStrs
		      Var tid As Integer = Val(s.Trim())
		      If tid > 0 Then tagIDs.Add(tid)
		    Next
		  End If
		  model.SetTagsForNote(id, tagIDs)

		  SetFlash("Note updated")
		  Redirect("/notes/" + Str(id))
		End Sub
	#tag EndMethod

End Class
#tag EndClass

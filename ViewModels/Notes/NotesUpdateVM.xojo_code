#tag Class
Protected Class NotesUpdateVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnPost()
		  Var id As Integer = Val(GetParam("id"))
		  Var title As String = GetFormValue("title")
		  Var body As String = GetFormValue("body")

		  If title.Length = 0 Then
		    SetFlash("Title is required", "error")
		    Redirect("/notes/" + Str(id) + "/edit")
		    Return
		  End If

		  Var model As New NoteModel()
		  model.Update(id, title, body)
		  SetFlash("Note updated")
		  Redirect("/notes/" + Str(id))
		End Sub
	#tag EndMethod

End Class
#tag EndClass

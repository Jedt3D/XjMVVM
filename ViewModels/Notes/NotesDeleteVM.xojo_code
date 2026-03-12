#tag Class
Protected Class NotesDeleteVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnPost()
		  If RequireLogin() Then Return

		  Var id As Integer = Val(GetParam("id"))
		  Var uid As Integer = CurrentUserID()
		  Var model As New NoteModel()
		  model.Delete(id, uid)
		  SetFlash("Note deleted")
		  Redirect("/notes")
		End Sub
	#tag EndMethod

End Class
#tag EndClass

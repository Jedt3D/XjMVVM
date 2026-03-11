#tag Class
Protected Class NotesDeleteVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnPost()
		  Var id As Integer = Val(GetParam("id"))
		  Var model As New NoteModel()
		  model.Delete(id)
		  SetFlash("Note deleted")
		  Redirect("/notes")
		End Sub
	#tag EndMethod

End Class
#tag EndClass

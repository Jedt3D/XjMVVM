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
		  Call model.Create(title, body)
		  SetFlash("Note created")
		  Redirect("/notes")
		End Sub
	#tag EndMethod

End Class
#tag EndClass

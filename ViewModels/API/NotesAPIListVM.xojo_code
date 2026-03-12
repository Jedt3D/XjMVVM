#tag Class
Protected Class NotesAPIListVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnGet()
		  If RequireLoginJSON() Then Return

		  Var uid As Integer = CurrentUserID()
		  Var model As New NoteModel()
		  Var notes() As Variant = model.GetAll(uid)
		  WriteJSON(JSONSerializer.ArrayToJSON(notes))
		End Sub
	#tag EndMethod

End Class
#tag EndClass

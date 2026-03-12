#tag Class
Protected Class NotesAPIListVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnGet()
		  Var model As New NoteModel()
		  Var notes() As Variant = model.GetAll()
		  WriteJSON(JSONSerializer.ArrayToJSON(notes))
		End Sub
	#tag EndMethod

End Class
#tag EndClass

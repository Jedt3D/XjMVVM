#tag Class
Protected Class NotesAPICreateVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnPost()
		  Var title As String = GetFormValue("title").Trim()
		  Var body As String = GetFormValue("body")

		  If title.Length = 0 Then
		    Response.Status = 422
		    WriteJSON("{""error"":""Title is required""}")
		    Return
		  End If

		  Var model As New NoteModel()
		  Var newID As Integer = model.Create(title, body)
		  Var note As Dictionary = model.GetByID(newID)

		  Response.Status = 201
		  WriteJSON(JSONSerializer.DictToJSON(note))
		End Sub
	#tag EndMethod

End Class
#tag EndClass

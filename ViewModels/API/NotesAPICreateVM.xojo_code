#tag Class
Protected Class NotesAPICreateVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnPost()
		  If RequireLoginJSON() Then Return

		  Var title As String = GetFormValue("title").Trim()
		  Var body As String = GetFormValue("body")

		  If title.Length = 0 Then
		    Response.Status = 422
		    WriteJSON("{""error"":""Title is required""}")
		    Return
		  End If

		  Var uid As Integer = CurrentUserID()
		  Var model As New NoteModel()
		  Var newID As Integer = model.Create(title, body, uid)
		  Var note As Dictionary = model.GetByID(newID, uid)

		  Response.Status = 201
		  WriteJSON(JSONSerializer.DictToJSON(note))
		End Sub
	#tag EndMethod

End Class
#tag EndClass

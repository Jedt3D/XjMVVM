#tag Class
Protected Class NotesListVM
Inherits BaseViewModel
	#tag Method, Flags = &h0
		Sub OnGet()
		  If RequireLogin() Then Return

		  Const perPage As Integer = 10
		  Var uid As Integer = CurrentUserID()

		  Var page As Integer = Val(GetParam("page"))
		  If page < 1 Then page = 1

		  Var model As New NoteModel()
		  Var total As Integer = model.CountForUser(uid)
		  Var totalPages As Integer = If(total = 0, 1, (total + perPage - 1) \ perPage)
		  If page > totalPages Then page = totalPages

		  Var offset As Integer = (page - 1) * perPage
		  Var notes() As Variant = model.FindPaginatedForUser(uid, perPage, offset, "updated_at DESC")

		  Var pagination As New Dictionary()
		  pagination.Value("page") = Str(page)
		  pagination.Value("per_page") = Str(perPage)
		  pagination.Value("total") = Str(total)
		  pagination.Value("total_pages") = Str(totalPages)
		  pagination.Value("has_prev") = If(page > 1, "1", "0")
		  pagination.Value("has_next") = If(page < totalPages, "1", "0")
		  pagination.Value("prev_page") = Str(page - 1)
		  pagination.Value("next_page") = Str(page + 1)

		  Var context As New Dictionary()
		  context.Value("page_title") = "Notes"
		  context.Value("notes") = notes
		  context.Value("pagination") = pagination
		  Render("notes/list.html", context)
		End Sub
	#tag EndMethod

End Class
#tag EndClass

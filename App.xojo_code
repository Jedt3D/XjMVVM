#tag Class
Protected Class App
Inherits WebApplication
	#tag Event
		Function HandleURL(request As WebRequest, response As WebResponse) As Boolean
		  // Normalize path (request.Path may lack leading slash in Xojo Web 2)
		  Var p As String = request.Path
		  If p.Left(1) <> "/" Then p = "/" + p
		  If p.Length > 1 And p.Right(1) = "/" Then p = p.Left(p.Length - 1)

		  // Xojo bootstrap entry point: Return False so Xojo serves bootstrap HTML + WebSocket
		  If p = "/" And request.QueryString = "_xojo=1" Then
		    Return False
		  End If

		  // /tests: redirect to Xojo bootstrap at root so Default page loads, then trampoline to XojoUnitTestPage
		  If p = "/tests" Then
		    response.Status = 302
		    response.Header("Location") = "/?_xojo=1"
		    response.Header("Content-Type") = "text/html; charset=utf-8"
		    response.Write("<html><head><meta http-equiv=""refresh"" content=""0;url=/?_xojo=1""></head><body>Redirecting...</body></html>")
		    Return True
		  End If

		  // All other paths: SSR router handles known routes.
		  // Unknown paths (Xojo framework JS/CSS resources) return False
		  // so Xojo serves its own framework files for the active WebSocket session.
		  Return mRouter.Route(request, response, mJinja, Session)
		End Function
	#tag EndEvent

	#tag Event
		Sub Opening(args() As String)
		  #Pragma Unused args
		  
		  // Initialize database
		  DBAdapter.InitDB()
		  
		  // Configure JinjaX template environment
		  mJinja = New JinjaX.JinjaEnvironment()
		  mJinja.Autoescape = True
		  mJinja.TrimBlocks = True
		  mJinja.LStripBlocks = True
		  Var templateFolder As New FolderItem("/Users/worajedt/Xojo Projects/mvvm/templates", FolderItem.PathModes.Native)
		  mJinja.SetLoader(New JinjaX.FileSystemLoader(templateFolder))
		  
		  // Set up Router and register routes
		  mRouter = New Router()
		  mRouter.Get("/", AddressOf CreateHomeVM)
		  
		  // Notes CRUD routes
		  mRouter.Get("/notes", AddressOf CreateNotesListVM)
		  mRouter.Get("/notes/new", AddressOf CreateNotesNewVM)
		  mRouter.Post("/notes", AddressOf CreateNotesCreateVM)
		  mRouter.Get("/notes/:id", AddressOf CreateNotesDetailVM)
		  mRouter.Get("/notes/:id/edit", AddressOf CreateNotesEditVM)
		  mRouter.Post("/notes/:id", AddressOf CreateNotesUpdateVM)
		  mRouter.Post("/notes/:id/delete", AddressOf CreateNotesDeleteVM)
		End Sub
	#tag EndEvent


	#tag Method, Flags = &h21
		Private Function CreateHomeVM() As BaseViewModel
		  Return New HomeViewModel()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function CreateNotesCreateVM() As BaseViewModel
		  Return New NotesCreateVM()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function CreateNotesDeleteVM() As BaseViewModel
		  Return New NotesDeleteVM()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function CreateNotesDetailVM() As BaseViewModel
		  Return New NotesDetailVM()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function CreateNotesEditVM() As BaseViewModel
		  Return New NotesEditVM()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function CreateNotesListVM() As BaseViewModel
		  Return New NotesListVM()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function CreateNotesNewVM() As BaseViewModel
		  Return New NotesNewVM()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function CreateNotesUpdateVM() As BaseViewModel
		  Return New NotesUpdateVM()
		End Function
	#tag EndMethod


	#tag Property, Flags = &h0
		mJinja As JinjaX.JinjaEnvironment
	#tag EndProperty

	#tag Property, Flags = &h0
		mRouter As Router
	#tag EndProperty


	#tag ViewBehavior
	#tag EndViewBehavior
End Class
#tag EndClass

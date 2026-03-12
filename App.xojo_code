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
		  
		  // /dist/: serve static files from templates/dist/
		  If p = "/dist" Then
		    response.Status = 302
		    response.Header("Location") = "/dist/"
		    Return True
		  End If
		  If p.Left(6) = "/dist/" Then
		    Return ServeStatic(p.Middle(6), response)
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
		  Var templateFolder As FolderItem = App.ExecutableFile.Parent.Child("templates")
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

		  // Tags CRUD routes
		  mRouter.Get("/tags", AddressOf CreateTagsListVM)
		  mRouter.Get("/tags/new", AddressOf CreateTagsNewVM)
		  mRouter.Post("/tags", AddressOf CreateTagsCreateVM)
		  mRouter.Get("/tags/:id", AddressOf CreateTagsDetailVM)
		  mRouter.Get("/tags/:id/edit", AddressOf CreateTagsEditVM)
		  mRouter.Post("/tags/:id", AddressOf CreateTagsUpdateVM)
		  mRouter.Post("/tags/:id/delete", AddressOf CreateTagsDeleteVM)

		  // Auth routes
		  mRouter.Get("/login", AddressOf CreateLoginVM)
		  mRouter.Post("/login", AddressOf CreateLoginVM)
		  mRouter.Post("/logout", AddressOf CreateLogoutVM)
		  mRouter.Get("/signup", AddressOf CreateSignupVM)
		  mRouter.Post("/signup", AddressOf CreateSignupVM)
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

	#tag Method, Flags = &h21
		Private Function CreateTagsListVM() As BaseViewModel
		  Return New TagsListVM()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function CreateTagsDetailVM() As BaseViewModel
		  Return New TagsDetailVM()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function CreateTagsNewVM() As BaseViewModel
		  Return New TagsNewVM()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function CreateTagsCreateVM() As BaseViewModel
		  Return New TagsCreateVM()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function CreateTagsEditVM() As BaseViewModel
		  Return New TagsEditVM()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function CreateTagsUpdateVM() As BaseViewModel
		  Return New TagsUpdateVM()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function CreateTagsDeleteVM() As BaseViewModel
		  Return New TagsDeleteVM()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function CreateLoginVM() As BaseViewModel
		  Return New LoginVM()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function CreateLogoutVM() As BaseViewModel
		  Return New LogoutVM()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function CreateSignupVM() As BaseViewModel
		  Return New SignupVM()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ServeStatic(relativePath As String, response As WebResponse) As Boolean
		  // Resolve file safely by walking Child() per segment (prevents path traversal)
		  Var f As FolderItem = App.ExecutableFile.Parent.Child("templates").Child("dist")
		  Var parts() As String = relativePath.Split("/")
		  For Each part As String In parts
		    If part = "" Or part = "." Or part = ".." Then Continue
		    f = f.Child(part)
		    If f Is Nil Or Not f.Exists Then
		      response.Status = 404
		      response.Header("Content-Type") = "text/plain"
		      response.Write("Not found")
		      Return True
		    End If
		  Next
		  // Directory → try index.html
		  If f.IsFolder Then
		    f = f.Child("index.html")
		    If f Is Nil Or Not f.Exists Then
		      response.Status = 404
		      response.Header("Content-Type") = "text/plain"
		      response.Write("Not found")
		      Return True
		    End If
		  End If
		  // Content-Type by extension
		  Var ext As String = f.Name.Lowercase
		  Var ct As String = "application/octet-stream"
		  If ext.EndsWith(".html") Then ct = "text/html; charset=utf-8"
		  If ext.EndsWith(".css")  Then ct = "text/css"
		  If ext.EndsWith(".js")   Then ct = "application/javascript"
		  If ext.EndsWith(".svg")  Then ct = "image/svg+xml"
		  If ext.EndsWith(".png")  Then ct = "image/png"
		  If ext.EndsWith(".ico")  Then ct = "image/x-icon"
		  If ext.EndsWith(".woff2") Then ct = "font/woff2"
		  // Read and serve
		  Var bs As BinaryStream = BinaryStream.Open(f)
		  Var content As String = bs.Read(bs.Length)
		  bs.Close()
		  response.Status = 200
		  response.Header("Content-Type") = ct
		  response.Write(content)
		  Return True
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

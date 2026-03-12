#tag Class
Protected Class Router
	#tag Method, Flags = &h0, Description = "Registers a GET route."
		Sub Get(pattern As String, factory As Router.VMFactory)
		  Var route As New RouteDefinition()
		  route.Method = "GET"
		  route.Pattern = pattern
		  route.Factory = factory
		  mRoutes.Add(route)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Registers a POST route."
		Sub Post(pattern As String, factory As Router.VMFactory)
		  Var route As New RouteDefinition()
		  route.Method = "POST"
		  route.Pattern = pattern
		  route.Factory = factory
		  mRoutes.Add(route)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Registers a route that handles both GET and POST."
		Sub Any(pattern As String, factory As Router.VMFactory)
		  Var route As New RouteDefinition()
		  route.Method = "*"
		  route.Pattern = pattern
		  route.Factory = factory
		  mRoutes.Add(route)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Matches the request to a route and dispatches to the ViewModel. Returns True if matched, False if no route matched."
		Function Route(request As WebRequest, response As WebResponse, jinja As JinjaX.JinjaEnvironment, session As WebSession) As Boolean
		  Var path As String = request.Path

		  // Normalize: ensure leading slash, strip trailing slash (except root)
		  If path.Left(1) <> "/" Then path = "/" + path
		  If path.Length > 1 And path.Right(1) = "/" Then
		    path = path.Left(path.Length - 1)
		  End If

		  // Try each registered route in order
		  For i As Integer = 0 To mRoutes.Count - 1
		    Var route As RouteDefinition = mRoutes(i)

		    // Check method match
		    If route.Method <> "*" And route.Method <> request.Method Then
		      Continue
		    End If

		    // Check path match
		    Var params As Dictionary = ParsePath(route.Pattern, path)
		    If params <> Nil Then
		      // Match found — create and dispatch ViewModel
		      Try
		        Var vm As BaseViewModel = route.Factory.Invoke()
		        vm.Request = request
		        vm.Response = response
		        vm.Session = session
		        vm.Jinja = jinja
		        vm.PathParams = params
		        vm.Handle()
		      Catch err As RuntimeException
		        Serve500(response, jinja, err.Message)
		      End Try
		      Return True
		    End If
		  Next

		  // No route matched — return False so HandleURL can delegate to Xojo
		  Return False
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Matches a pattern against an actual path. Returns a Dictionary of params or Nil if no match."
		Function ParsePath(pattern As String, actual As String) As Dictionary
		  Var patternParts() As String = pattern.Split("/")
		  Var actualParts() As String = actual.Split("/")

		  If patternParts.Count <> actualParts.Count Then Return Nil

		  Var params As New Dictionary()

		  For i As Integer = 0 To patternParts.Count - 1
		    Var pp As String = patternParts(i)
		    Var ap As String = actualParts(i)

		    If pp.Left(1) = ":" Then
		      // Parameter segment — strip leading ':' and capture
		      Var paramName As String = pp.Right(pp.Length - 1)
		      params.Value(paramName) = ap
		    ElseIf pp <> ap Then
		      // Literal segment doesn't match
		      Return Nil
		    End If
		  Next

		  Return params
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Sends a 404 Not Found response."
		Sub Serve404(response As WebResponse, jinja As JinjaX.JinjaEnvironment)
		  response.Status = 404
		  Try
		    Var ctx As New Dictionary()
		    ctx.Value("status_code") = 404
		    ctx.Value("message") = "Page Not Found"
		    Var tmpl As JinjaX.CompiledTemplate = jinja.GetTemplate("errors/404.html")
		    Var html As String = tmpl.Render(ctx)
		    response.Header("Content-Type") = "text/html; charset=utf-8"
		    response.Write(html)
		  Catch
		    response.Header("Content-Type") = "text/html; charset=utf-8"
		    response.Write("<h1>404</h1><p>Page Not Found</p>")
		  End Try
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Sends a 500 Internal Server Error response."
		Sub Serve500(response As WebResponse, jinja As JinjaX.JinjaEnvironment, errorMsg As String)
		  response.Status = 500
		  Try
		    Var ctx As New Dictionary()
		    ctx.Value("status_code") = 500
		    ctx.Value("message") = errorMsg
		    Var tmpl As JinjaX.CompiledTemplate = jinja.GetTemplate("errors/500.html")
		    Var html As String = tmpl.Render(ctx)
		    response.Header("Content-Type") = "text/html; charset=utf-8"
		    response.Write(html)
		  Catch
		    response.Header("Content-Type") = "text/html; charset=utf-8"
		    response.Write("<h1>500</h1><p>Internal Server Error</p>")
		  End Try
		End Sub
	#tag EndMethod


	#tag DelegateDeclaration, Name = VMFactory, Flags = &h0, Description = "Delegate that creates a new BaseViewModel instance for each request."
		Delegate Function VMFactory() As BaseViewModel
	#tag EndDelegateDeclaration

	#tag Property, Flags = &h21
		Private mRoutes() As RouteDefinition
	#tag EndProperty


	#tag ViewBehavior
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			InitialValue=""
			Type="String"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			InitialValue="-2147483648"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			InitialValue=""
			Type="String"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Left"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Top"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass

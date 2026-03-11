#tag Class
Protected Class BuiltInFilters
	#tag Method, Flags = &h1
		Shared Sub RegisterAll(env As JinjaX.JinjaEnvironment)
		  env.RegisterFilter("upper", AddressOf FilterUpper)
		  env.RegisterFilter("lower", AddressOf FilterLower)
		  env.RegisterFilter("title", AddressOf FilterTitle)
		  env.RegisterFilter("capitalize", AddressOf FilterCapitalize)
		  env.RegisterFilter("trim", AddressOf FilterTrim)
		  env.RegisterFilter("length", AddressOf FilterLength)
		  env.RegisterFilter("default", AddressOf FilterDefault)
		  env.RegisterFilter("d", AddressOf FilterDefault)
		  env.RegisterFilter("int", AddressOf FilterInt)
		  env.RegisterFilter("float", AddressOf FilterFloat)
		  env.RegisterFilter("string", AddressOf FilterString)
		  env.RegisterFilter("join", AddressOf FilterJoin)
		  env.RegisterFilter("replace", AddressOf FilterReplace)
		  env.RegisterFilter("first", AddressOf FilterFirst)
		  env.RegisterFilter("last", AddressOf FilterLast)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h1
		Shared Function FilterUpper(value As Variant, args() As Variant) As Variant
		  #Pragma Unused args
		  Return CStr(value).Uppercase()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Shared Function FilterLower(value As Variant, args() As Variant) As Variant
		  #Pragma Unused args
		  Return CStr(value).Lowercase()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Shared Function FilterTitle(value As Variant, args() As Variant) As Variant
		  #Pragma Unused args
		  Return CStr(value).Titlecase()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Shared Function FilterCapitalize(value As Variant, args() As Variant) As Variant
		  #Pragma Unused args
		  Var s As String = CStr(value)
		  If s.Length = 0 Then Return ""
		  Return s.Left(1).Uppercase() + s.Mid(2).Lowercase()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Shared Function FilterTrim(value As Variant, args() As Variant) As Variant
		  #Pragma Unused args
		  Return CStr(value).Trim()
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Shared Function FilterLength(value As Variant, args() As Variant) As Variant
		  #Pragma Unused args
		  Return CStr(value).Length
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Shared Function FilterDefault(value As Variant, args() As Variant) As Variant
		  // Return default value if value is Nil or empty string
		  Var isEmpty As Boolean = False
		  If value.Type = Variant.TypeNil Then
		    isEmpty = True
		  ElseIf value.Type = Variant.TypeString Then
		    If CStr(value) = "" Then isEmpty = True
		  End If

		  If isEmpty Then
		    If args.Count > 0 Then
		      Return args(0)
		    End If
		    Return ""
		  End If
		  Return value
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Shared Function FilterInt(value As Variant, args() As Variant) As Variant
		  #Pragma Unused args
		  Try
		    Return CType(CDbl(value), Integer)
		  Catch
		    If args.Count > 0 Then Return args(0)
		    Return 0
		  End Try
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Shared Function FilterFloat(value As Variant, args() As Variant) As Variant
		  #Pragma Unused args
		  Try
		    Return CDbl(value)
		  Catch
		    If args.Count > 0 Then Return args(0)
		    Return 0.0
		  End Try
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Shared Function FilterString(value As Variant, args() As Variant) As Variant
		  #Pragma Unused args
		  If value.Type = Variant.TypeNil Then Return ""
		  Return CStr(value)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Shared Function FilterJoin(value As Variant, args() As Variant) As Variant
		  Var sep As String = ""
		  If args.Count > 0 Then sep = CStr(args(0))

		  // Value should be a string representation of items for now
		  // Full array support comes with the renderer
		  Return CStr(value)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Shared Function FilterReplace(value As Variant, args() As Variant) As Variant
		  Var s As String = CStr(value)
		  If args.Count >= 2 Then
		    Var search As String = CStr(args(0))
		    Var replacement As String = CStr(args(1))
		    Return s.ReplaceAll(search, replacement)
		  End If
		  Return s
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Shared Function FilterFirst(value As Variant, args() As Variant) As Variant
		  #Pragma Unused args
		  Var s As String = CStr(value)
		  If s.Length > 0 Then Return s.Left(1)
		  Return ""
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Shared Function FilterLast(value As Variant, args() As Variant) As Variant
		  #Pragma Unused args
		  Var s As String = CStr(value)
		  If s.Length > 0 Then Return s.Right(1)
		  Return ""
		End Function
	#tag EndMethod


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

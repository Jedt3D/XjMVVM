#tag Class
Protected Class CompiledTemplate
	#tag Method, Flags = &h0
		Sub Constructor(env As JinjaX.JinjaEnvironment, ast As JinjaX.TemplateNode)
		  mEnvironment = env
		  mAST = ast
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetAST() As JinjaX.TemplateNode
		  Return mAST
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetEnvironment() As JinjaX.JinjaEnvironment
		  Return mEnvironment
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Render(variables As Dictionary) As String
		  Var ctx As New JinjaX.JinjaContext()

		  // Load variables into context
		  If variables <> Nil Then
		    Var keys() As Variant = variables.Keys()
		    For i As Integer = 0 To keys.Count - 1
		      ctx.SetVariable(CStr(keys(i)), variables.Value(keys(i)))
		    Next
		  End If

		  Var renderer As New JinjaX.JinjaRenderer(mEnvironment, ctx)
		  Return renderer.Render(mAST)
		End Function
	#tag EndMethod


	#tag Property, Flags = &h21
		Private mEnvironment As JinjaX.JinjaEnvironment
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mAST As JinjaX.TemplateNode
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

#tag Class
Protected Class JinjaContext
	#tag Method, Flags = &h0
		Sub Constructor()
		  // Initialize with a single global scope
		  mScopes.Add(New Dictionary())
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub PushScope()
		  mScopes.Add(New Dictionary())
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub PopScope()
		  If mScopes.Count > 1 Then
		    mScopes.RemoveAt(mScopes.Count - 1)
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SetVariable(key As String, value As Variant)
		  // Set in the current (innermost) scope
		  mScopes(mScopes.Count - 1).Value(key) = value
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetVariable(key As String) As Variant
		  // Search from innermost to outermost scope
		  For i As Integer = mScopes.Count - 1 DownTo 0
		    If mScopes(i).HasKey(key) Then
		      Return mScopes(i).Value(key)
		    End If
		  Next
		  Return Nil
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function HasVariable(key As String) As Boolean
		  For i As Integer = mScopes.Count - 1 DownTo 0
		    If mScopes(i).HasKey(key) Then
		      Return True
		    End If
		  Next
		  Return False
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SetGlobalVariable(key As String, value As Variant)
		  // Set in the outermost (global) scope
		  mScopes(0).Value(key) = value
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function ScopeDepth() As Integer
		  Return mScopes.Count
		End Function
	#tag EndMethod


	#tag Property, Flags = &h21
		Private mScopes() As Dictionary
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

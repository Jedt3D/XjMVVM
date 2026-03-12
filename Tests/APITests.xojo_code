#tag Class
Protected Class APITests
Inherits TestGroup
	#tag Event
		Sub TearDown()
		  Var noteModel As New NoteModel()
		  Var tagModel As New TagModel()
		  For Each id As Integer In mNoteIDs
		    noteModel.Delete(id)
		  Next
		  mNoteIDs.RemoveAll()
		  For Each id As Integer In mTagIDs
		    tagModel.Delete(id)
		  Next
		  mTagIDs.RemoveAll()
		End Sub
	#tag EndEvent


	#tag Method, Flags = &h0, Description = "Note serialized as JSON includes expected keys."
		Sub NoteToJSONIncludesKeysTest()
		  Var noteModel As New NoteModel()
		  Var id As Integer = noteModel.Create("API Test Note", "body text")
		  mNoteIDs.Add(id)

		  Var note As Dictionary = noteModel.GetByID(id)
		  Var json As String = DictToJSON(note)

		  Assert.IsTrue(json.IndexOf("""id""") >= 0, "JSON should contain id key")
		  Assert.IsTrue(json.IndexOf("""title""") >= 0, "JSON should contain title key")
		  Assert.IsTrue(json.IndexOf("""body""") >= 0, "JSON should contain body key")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Tag serialized as JSON includes expected keys."
		Sub TagToJSONIncludesKeysTest()
		  Var tagModel As New TagModel()
		  Var id As Integer = tagModel.Create("APITag")
		  mTagIDs.Add(id)

		  Var tag As Dictionary = tagModel.GetByID(id)
		  Var json As String = DictToJSON(tag)

		  Assert.IsTrue(json.IndexOf("""id""") >= 0, "JSON should contain id key")
		  Assert.IsTrue(json.IndexOf("""name""") >= 0, "JSON should contain name key")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Notes array serialized as JSON is a valid array."
		Sub NotesArrayToJSONIsArrayTest()
		  Var noteModel As New NoteModel()
		  Var id As Integer = noteModel.Create("Array JSON Test", "")
		  mNoteIDs.Add(id)

		  Var notes() As Variant = noteModel.GetAll()
		  Var json As String = ArrayToJSON(notes)

		  Assert.IsTrue(json.Left(1) = "[", "JSON array should start with [")
		  Assert.IsTrue(json.Right(1) = "]", "JSON array should end with ]")
		End Sub
	#tag EndMethod


	#tag Method, Flags = &h21, Description = "Serializes a Dictionary to a JSON object string."
		Private Function DictToJSON(d As Dictionary) As String
		  Var parts() As String
		  For Each key As Variant In d.Keys
		    Var k As String = key.StringValue
		    Var v As String = d.Value(key).StringValue
		    // Escape double quotes in value
		    v = v.ReplaceAll("\", "\\")
		    v = v.ReplaceAll("""", "\""")
		    parts.Add("""" + k + """" + ":" + """" + v + """")
		  Next
		  Return "{" + String.FromArray(parts, ",") + "}"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21, Description = "Serializes a Variant() of Dictionary to a JSON array string."
		Private Function ArrayToJSON(items() As Variant) As String
		  Var parts() As String
		  For Each item As Variant In items
		    Var d As Dictionary = item
		    parts.Add(DictToJSON(d))
		  Next
		  Return "[" + String.FromArray(parts, ",") + "]"
		End Function
	#tag EndMethod


	#tag Property, Flags = &h21
		Private mNoteIDs() As Integer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mTagIDs() As Integer
	#tag EndProperty


	#tag ViewBehavior
		#tag ViewProperty
			Name="Duration"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="Double"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="FailedTestCount"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="IncludeGroup"
			Visible=false
			Group="Behavior"
			InitialValue="True"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="IsRunning"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="NotImplementedCount"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="PassedTestCount"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="RunTestCount"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="SkippedTestCount"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="StopTestOnFail"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="TestCount"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="Integer"
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
			Name="Left"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			InitialValue=""
			Type="String"
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

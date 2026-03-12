#tag Class
Protected Class NoteOwnershipTests
Inherits TestGroup
	#tag Event
		Sub TearDown()
		  Const kTestUserID As Integer = 999
		  Var model As New NoteModel()
		  For Each id As Integer In mTestIDs
		    model.Delete(id, kTestUserID)
		  Next
		  mTestIDs.RemoveAll()
		End Sub
	#tag EndEvent


	#tag Method, Flags = &h0, Description = "GetByID returns Nil when fetched by a different user."
		Sub GetByIDReturnsNilForWrongUserTest()
		  Const kTestUserID As Integer = 999
		  Const kOtherUserID As Integer = 888
		  Var model As New NoteModel()
		  Var id As Integer = model.Create("Ownership Test", "body", kTestUserID)
		  mTestIDs.Add(id)

		  Var note As Dictionary = model.GetByID(id, kOtherUserID)
		  Assert.IsNil(note, "GetByID should return Nil for wrong user")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Delete by wrong user does not remove the note."
		Sub DeleteDoesNotAffectOtherUsersNoteTest()
		  Const kTestUserID As Integer = 999
		  Const kOtherUserID As Integer = 888
		  Var model As New NoteModel()
		  Var id As Integer = model.Create("Protected Note", "body", kTestUserID)
		  mTestIDs.Add(id)

		  model.Delete(id, kOtherUserID)

		  Var note As Dictionary = model.GetByID(id, kTestUserID)
		  Assert.IsNotNil(note, "Delete by wrong user should not remove the note")
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h21
		Private mTestIDs() As Integer
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

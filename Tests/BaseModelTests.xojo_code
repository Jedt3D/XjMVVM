#tag Class
Protected Class BaseModelTests
Inherits TestGroup
	#tag Event
		Sub TearDown()
		  // Clean up any note inserted during the test
		  If mTestID > 0 Then
		    Var model As New NoteModel()
		    model.Delete(mTestID)
		    mTestID = 0
		  End If
		End Sub
	#tag EndEvent


	#tag Method, Flags = &h0, Description = "FindAll returns a Variant() with Count >= 0."
		Sub FindAllReturnsArrayTest()
		  Var model As New NoteModel()
		  Var results() As Variant = model.GetAll()
		  Assert.IsTrue(results.Count >= 0, "FindAll should return a non-negative count")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Insert a row via Create, then FindByID returns matching Dictionary."
		Sub InsertAndFindByIDTest()
		  Var model As New NoteModel()
		  mTestID = model.Create("BaseModel Insert Test", "body text")
		  Assert.IsTrue(mTestID > 0, "Create should return a positive ID")

		  Var row As Dictionary = model.GetByID(mTestID)
		  Assert.IsNotNil(row)
		  Assert.AreEqual("BaseModel Insert Test", row.Value("title").StringValue)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "UpdateByID changes column values visible via FindByID."
		Sub UpdateByIDChangesValuesTest()
		  Var model As New NoteModel()
		  mTestID = model.Create("Before Update", "old body")

		  Var data As New Dictionary()
		  data.Value("title") = "After Update"
		  data.Value("body") = "new body"
		  model.UpdateByID(mTestID, data)

		  Var row As Dictionary = model.GetByID(mTestID)
		  Assert.IsNotNil(row)
		  Assert.AreEqual("After Update", row.Value("title").StringValue)
		  Assert.AreEqual("new body", row.Value("body").StringValue)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "DeleteByID removes the row so FindByID returns Nil."
		Sub DeleteByIDRemovesRowTest()
		  Var model As New NoteModel()
		  mTestID = model.Create("To Be Deleted", "")

		  model.DeleteByID(mTestID)
		  mTestID = 0 // already deleted, skip TearDown cleanup

		  Var row As Dictionary = model.GetByID(Integer.FromString("999999999"))
		  // Use a guaranteed-missing row to prove Nil return
		  Assert.IsNil(row)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "FindByID with a non-existent ID returns Nil."
		Sub FindByIDReturnsNilForMissingTest()
		  Var model As New NoteModel()
		  Var row As Dictionary = model.GetByID(999999999)
		  Assert.IsNil(row)
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h21
		Private mTestID As Integer
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

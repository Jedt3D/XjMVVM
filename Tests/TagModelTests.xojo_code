#tag Class
Protected Class TagModelTests
Inherits TestGroup
	#tag Event
		Sub TearDown()
		  If mTestID > 0 Then
		    Var model As New TagModel()
		    model.Delete(mTestID)
		    mTestID = 0
		  End If
		End Sub
	#tag EndEvent


	#tag Method, Flags = &h0, Description = "Create returns a positive integer ID."
		Sub CreateReturnsIDTest()
		  Var model As New TagModel()
		  mTestID = model.Create("TestTag")
		  Assert.IsTrue(mTestID > 0, "Create should return a positive ID")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "GetAll includes the newly created tag."
		Sub GetAllIncludesNewTagTest()
		  Var model As New TagModel()
		  mTestID = model.Create("GetAll Test Tag")

		  Var results() As Variant = model.GetAll()
		  Var found As Boolean = False
		  For Each item As Variant In results
		    Var row As Dictionary = item
		    If row.Value("id").StringValue = CStr(mTestID) Then
		      found = True
		    End If
		  Next
		  Assert.IsTrue(found, "GetAll should include the newly created tag")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "GetByID returns the correct name for the created tag."
		Sub GetByIDMatchesNameTest()
		  Var model As New TagModel()
		  mTestID = model.Create("SpecificTagName")

		  Var row As Dictionary = model.GetByID(mTestID)
		  Assert.IsNotNil(row)
		  Assert.AreEqual("SpecificTagName", row.Value("name").StringValue)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Update changes the name visible via GetByID."
		Sub UpdateChangesNameTest()
		  Var model As New TagModel()
		  mTestID = model.Create("Original Name")
		  model.Update(mTestID, "Updated Name")

		  Var row As Dictionary = model.GetByID(mTestID)
		  Assert.IsNotNil(row)
		  Assert.AreEqual("Updated Name", row.Value("name").StringValue)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Delete removes the tag so GetByID returns Nil."
		Sub DeleteRemovesTagTest()
		  Var model As New TagModel()
		  Var tempID As Integer = model.Create("To Delete")
		  model.Delete(tempID)

		  Var row As Dictionary = model.GetByID(tempID)
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

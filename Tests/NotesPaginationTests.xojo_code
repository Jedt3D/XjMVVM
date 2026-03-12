#tag Class
Protected Class NotesPaginationTests
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


	#tag Method, Flags = &h0, Description = "Count() returns a non-negative integer."
		Sub CountReturnsNonNegativeTest()
		  Const kTestUserID As Integer = 999
		  Var model As New NoteModel()
		  Var n As Integer = model.CountForUser(kTestUserID)
		  Assert.IsTrue(n >= 0, "Count should be >= 0")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Count() increases by 1 after creating a note."
		Sub CountIncreasesAfterCreateTest()
		  Const kTestUserID As Integer = 999
		  Var model As New NoteModel()
		  Var before As Integer = model.CountForUser(kTestUserID)
		  mTestIDs.Add(model.Create("Pag Count Test", "body", kTestUserID))
		  Var after As Integer = model.CountForUser(kTestUserID)
		  Assert.AreEqual(before + 1, after, "Count should increase by 1 after create")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "FindPaginated respects the limit parameter."
		Sub FindPaginatedRespectsLimitTest()
		  Const kTestUserID As Integer = 999
		  Var model As New NoteModel()
		  mTestIDs.Add(model.Create("Pag Limit A", "", kTestUserID))
		  mTestIDs.Add(model.Create("Pag Limit B", "", kTestUserID))
		  mTestIDs.Add(model.Create("Pag Limit C", "", kTestUserID))

		  Var page() As Variant = model.FindPaginatedForUser(kTestUserID, 2, 0, "id ASC")
		  Assert.IsTrue(page.Count <= 2, "FindPaginated(limit=2) should return at most 2 rows")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "FindPaginated offset returns different rows than page 1."
		Sub FindPaginatedOffsetReturnsDifferentRowsTest()
		  Const kTestUserID As Integer = 999
		  Var model As New NoteModel()
		  mTestIDs.Add(model.Create("Pag Offset A", "", kTestUserID))
		  mTestIDs.Add(model.Create("Pag Offset B", "", kTestUserID))
		  mTestIDs.Add(model.Create("Pag Offset C", "", kTestUserID))

		  Var page1() As Variant = model.FindPaginatedForUser(kTestUserID, 1, 0, "id ASC")
		  Var page2() As Variant = model.FindPaginatedForUser(kTestUserID, 1, 1, "id ASC")

		  If page1.Count = 0 Or page2.Count = 0 Then
		    Assert.IsTrue(False, "Both pages should return a row")
		    Return
		  End If

		  Var row1 As Dictionary = page1(0)
		  Var row2 As Dictionary = page2(0)
		  Assert.AreDifferent(row1.Value("id").StringValue, row2.Value("id").StringValue, "Different offsets should return different rows")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "FindPaginated with large offset returns empty array."
		Sub FindPaginatedLargeOffsetEmptyTest()
		  Const kTestUserID As Integer = 999
		  Var model As New NoteModel()
		  Var page() As Variant = model.FindPaginatedForUser(kTestUserID, 10, 99999, "id ASC")
		  Assert.IsTrue(page.Count = 0, "Large offset should return empty array")
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

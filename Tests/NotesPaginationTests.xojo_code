#tag Class
Protected Class NotesPaginationTests
Inherits TestGroup
	#tag Event
		Sub TearDown()
		  Var model As New NoteModel()
		  For Each id As Integer In mTestIDs
		    model.Delete(id)
		  Next
		  mTestIDs.RemoveAll()
		End Sub
	#tag EndEvent


	#tag Method, Flags = &h0, Description = "Count() returns a non-negative integer."
		Sub CountReturnsNonNegativeTest()
		  Var model As New NoteModel()
		  Var n As Integer = model.Count()
		  Assert.IsTrue(n >= 0, "Count should be >= 0")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Count() increases by 1 after creating a note."
		Sub CountIncreasesAfterCreateTest()
		  Var model As New NoteModel()
		  Var before As Integer = model.Count()
		  mTestIDs.Add(model.Create("Pag Count Test", "body"))
		  Var after As Integer = model.Count()
		  Assert.AreEqual(before + 1, after, "Count should increase by 1 after create")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "FindPaginated respects the limit parameter."
		Sub FindPaginatedRespectsLimitTest()
		  Var model As New NoteModel()
		  mTestIDs.Add(model.Create("Pag Limit A", ""))
		  mTestIDs.Add(model.Create("Pag Limit B", ""))
		  mTestIDs.Add(model.Create("Pag Limit C", ""))

		  Var page() As Variant = model.FindPaginated(2, 0, "id ASC")
		  Assert.IsTrue(page.Count <= 2, "FindPaginated(limit=2) should return at most 2 rows")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "FindPaginated offset returns different rows than page 1."
		Sub FindPaginatedOffsetReturnsDifferentRowsTest()
		  Var model As New NoteModel()
		  mTestIDs.Add(model.Create("Pag Offset A", ""))
		  mTestIDs.Add(model.Create("Pag Offset B", ""))
		  mTestIDs.Add(model.Create("Pag Offset C", ""))

		  Var page1() As Variant = model.FindPaginated(1, 0, "id ASC")
		  Var page2() As Variant = model.FindPaginated(1, 1, "id ASC")

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
		  Var model As New NoteModel()
		  Var page() As Variant = model.FindPaginated(10, 99999, "id ASC")
		  Assert.AreEqual(0, page.Count, "Large offset should return empty array")
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

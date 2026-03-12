#tag Class
Protected Class NoteTagAssociationTests
Inherits TestGroup
	#tag Event
		Sub TearDown()
		  Var noteModel As New NoteModel()
		  Var tagModel As New TagModel()
		  If mNoteID > 0 Then
		    noteModel.Delete(mNoteID)
		    mNoteID = 0
		  End If
		  For Each id As Integer In mTagIDs
		    tagModel.Delete(id)
		  Next
		  mTagIDs.RemoveAll()
		End Sub
	#tag EndEvent


	#tag Method, Flags = &h0, Description = "SetTagsForNote then GetTagsForNote returns the assigned tags."
		Sub SetAndGetTagsTest()
		  Var noteModel As New NoteModel()
		  Var tagModel As New TagModel()

		  mNoteID = noteModel.Create("Tagged Note", "body")
		  Var tag1ID As Integer = tagModel.Create("AssocTag1")
		  Var tag2ID As Integer = tagModel.Create("AssocTag2")
		  mTagIDs.Add(tag1ID)
		  mTagIDs.Add(tag2ID)

		  Var tagIDs() As Integer
		  tagIDs.Add(tag1ID)
		  tagIDs.Add(tag2ID)
		  noteModel.SetTagsForNote(mNoteID, tagIDs)

		  Var tags() As Variant = noteModel.GetTagsForNote(mNoteID)
		  Assert.AreEqual(2, tags.Count, "Should have 2 tags after SetTagsForNote")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "SetTagsForNote overwrites previous tags."
		Sub SetTagsOverwritesPreviousTest()
		  Var noteModel As New NoteModel()
		  Var tagModel As New TagModel()

		  mNoteID = noteModel.Create("Overwrite Test", "")
		  Var tag1ID As Integer = tagModel.Create("OvTag1")
		  Var tag2ID As Integer = tagModel.Create("OvTag2")
		  Var tag3ID As Integer = tagModel.Create("OvTag3")
		  mTagIDs.Add(tag1ID)
		  mTagIDs.Add(tag2ID)
		  mTagIDs.Add(tag3ID)

		  // Set 2 tags
		  Var tagIDs() As Integer
		  tagIDs.Add(tag1ID)
		  tagIDs.Add(tag2ID)
		  noteModel.SetTagsForNote(mNoteID, tagIDs)

		  // Overwrite with just 1 tag
		  Var newTagIDs() As Integer
		  newTagIDs.Add(tag3ID)
		  noteModel.SetTagsForNote(mNoteID, newTagIDs)

		  Var tags() As Variant = noteModel.GetTagsForNote(mNoteID)
		  Assert.AreEqual(1, tags.Count, "Should have 1 tag after overwrite")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "SetTagsForNote with empty array clears all tags."
		Sub SetEmptyTagsClearsAllTest()
		  Var noteModel As New NoteModel()
		  Var tagModel As New TagModel()

		  mNoteID = noteModel.Create("Clear Tags Test", "")
		  Var tag1ID As Integer = tagModel.Create("ClearTag1")
		  mTagIDs.Add(tag1ID)

		  Var tagIDs() As Integer
		  tagIDs.Add(tag1ID)
		  noteModel.SetTagsForNote(mNoteID, tagIDs)

		  // Clear
		  Var emptyIDs() As Integer
		  noteModel.SetTagsForNote(mNoteID, emptyIDs)

		  Var tags() As Variant = noteModel.GetTagsForNote(mNoteID)
		  Assert.AreEqual(0, tags.Count, "Should have 0 tags after clearing")
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h21
		Private mNoteID As Integer
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

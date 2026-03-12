#tag Class
Protected Class UserModelTests
Inherits TestGroup
	#tag Event
		Sub TearDown()
		  If mTestID > 0 Then
		    Var model As New UserModel()
		    model.DeleteByID(mTestID)
		    mTestID = 0
		  End If
		End Sub
	#tag EndEvent


	#tag Method, Flags = &h0, Description = "Create returns a positive integer ID."
		Sub CreateReturnsIDTest()
		  Var model As New UserModel()
		  mTestID = model.Create("testuser_" + Str(System.Ticks), "password123")
		  Assert.IsTrue(mTestID > 0, "Create should return a positive ID")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "FindByUsername returns the user after creation."
		Sub FindByUsernameTest()
		  Var model As New UserModel()
		  Var username As String = "findtest_" + Str(System.Ticks)
		  mTestID = model.Create(username, "pass")

		  Var row As Dictionary = model.FindByUsername(username)
		  Assert.IsNotNil(row, "FindByUsername should find the created user")
		  Assert.AreEqual(username, row.Value("username").StringValue)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "FindByUsername returns Nil for unknown user."
		Sub FindByUsernameUnknownReturnsNilTest()
		  Var model As New UserModel()
		  Var row As Dictionary = model.FindByUsername("no_such_user_xyz_12345")
		  Assert.IsNil(row, "FindByUsername should return Nil for unknown username")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "VerifyPassword returns True for correct password."
		Sub VerifyCorrectPasswordTest()
		  Var model As New UserModel()
		  Var username As String = "verify_" + Str(System.Ticks)
		  mTestID = model.Create(username, "correctpass")

		  Assert.IsTrue(model.VerifyPassword(username, "correctpass"), "Correct password should verify")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "VerifyPassword returns False for wrong password."
		Sub VerifyWrongPasswordTest()
		  Var model As New UserModel()
		  Var username As String = "wrongpass_" + Str(System.Ticks)
		  mTestID = model.Create(username, "realpass")

		  Assert.IsFalse(model.VerifyPassword(username, "wrongpass"), "Wrong password should not verify")
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

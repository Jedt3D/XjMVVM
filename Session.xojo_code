#tag Class
Protected Class Session
Inherits WebSession
#tag Session
  interruptmessage=We are having trouble communicating with the server. Please wait a moment while we attempt to reconnect.
  disconnectmessage=You have been disconnected from this application.
  confirmmessage=
  AllowTabOrderWrap=True
  ColorMode=0
  SendEventsInBatches=False
  LazyLoadDependencies=False
#tag EndSession
	#tag Method, Flags = &h0, Description = "Stores the authenticated user in the session."
		Sub LogIn(userID As Integer, username As String)
		  CurrentUserID = userID
		  CurrentUsername = username
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Clears the authenticated user from the session."
		Sub LogOut()
		  CurrentUserID = 0
		  CurrentUsername = ""
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Returns True if a user is logged in."
		Function IsLoggedIn() As Boolean
		  Return CurrentUserID > 0
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Sets a flash message to display on the next page load."
		Sub SetFlash(message As String, type As String = "success")
		  FlashMessage = message
		  FlashType = type
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = "Returns the flash message as a Dictionary and clears it. Returns Nil if no flash."
		Function GetFlash() As Dictionary
		  If FlashMessage.Length = 0 Then Return Nil

		  Var flash As New Dictionary()
		  flash.Value("message") = FlashMessage
		  flash.Value("type") = FlashType

		  // Clear after reading
		  FlashMessage = ""
		  FlashType = ""

		  Return flash
		End Function
	#tag EndMethod


	#tag Property, Flags = &h0
		CurrentUserID As Integer
	#tag EndProperty

	#tag Property, Flags = &h0
		CurrentUsername As String
	#tag EndProperty

	#tag Property, Flags = &h0
		FlashMessage As String
	#tag EndProperty

	#tag Property, Flags = &h0
		FlashType As String
	#tag EndProperty

End Class
#tag EndClass

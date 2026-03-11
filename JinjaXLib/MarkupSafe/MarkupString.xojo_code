#tag Class
Protected Class MarkupString
	#tag Method, Flags = &h0
		Sub Constructor()
		  mValue = ""
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Constructor(value As String)
		  If value = "" Then
		    mValue = ""
		  Else
		    mValue = value
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Escaped() As MarkupString
		  Return New MarkupString(MarkupSafe.EscapeString(mValue))
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function IsEmpty() As Boolean
		  Return mValue.Length = 0
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Length() As Integer
		    Return mValue.Length
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Lowercase() As MarkupString
		    Return New MarkupString(mValue.Lowercase)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Operator_Add(other As Variant) As MarkupString
		  Var otherStr As String
		  If other IsA MarkupString Then
		    otherStr = MarkupString(other).ToString()
		  Else
		    Try
		      otherStr = other.StringValue
		    Catch
		      otherStr = ""
		    End Try
		  End If
		  Return New MarkupString(mValue + otherStr)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Operator_Compare(other As Variant) As Integer
		  Var otherStr As String
		  If other IsA MarkupString Then
		    otherStr = MarkupString(other).ToString()
		  Else
		    Try
		      otherStr = other.StringValue
		    Catch
		      otherStr = ""
		    End Try
		  End If
		  If mValue < otherStr Then Return -1
		  If mValue > otherStr Then Return 1
		  Return 0
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function ToString() As String
		  Return mValue
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Trim() As MarkupString
		    Return New MarkupString(mValue.Trim)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Unescaped() As MarkupString
		    Return New MarkupString(MarkupSafe.UnescapeString(mValue))
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Uppercase() As MarkupString
		    Return New MarkupString(mValue.Uppercase)
		End Function
	#tag EndMethod


	#tag Property, Flags = &h0
		mValue As String
	#tag EndProperty


End Class
#tag EndClass

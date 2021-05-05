Namespace SubClassCtrl
    'From https://www.codeproject.com/Articles/3234/Subclassing-in-NET-The-pure-NET-way

    Public Class SubClassing
	Inherits System.Windows.Forms.NativeWindow

	Public Event CallBackProc(ByRef m As Message)

	Public Sub New(ByVal handle As IntPtr)
	    On Error GoTo Err

	    AssignHandle(handle)

	    Exit Sub
Err:
	    ErrCode = Err.Number
	    MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

	End Sub

	Public Property SubClass() As Boolean = False

	Protected Overrides Sub WndProc(ByRef m As Message)
	    On Error GoTo Err

	    If SubClass Then
		RaiseEvent CallBackProc(m)
	    End If
	    MyBase.WndProc(m)

	    Exit Sub
Err:
	    ErrCode = Err.Number
	    MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

	End Sub

	Protected Overrides Sub Finalize()
	    On Error GoTo Err

	    MyBase.Finalize()

	    Exit Sub
Err:
	    ErrCode = Err.Number
	    MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

	End Sub

    End Class

End Namespace

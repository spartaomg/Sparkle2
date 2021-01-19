
Imports System.ComponentModel

Public Class FrmDisk

    Private Sub FrmDisk_Load(sender As Object, e As EventArgs) Handles MyBase.Load
        On Error GoTo Err

        Application.UseWaitCursor = True

        Pbx1.Top = (Height - Pbx1.Height) / 2

        Lbl.Left = Pbx1.Left + Pbx1.Width + ((Width - Lbl.Width - Pbx1.Left - Pbx1.Width) / 2)
        Lbl.Top = (Height - Lbl.Height) / 2

        Cursor = Cursors.WaitCursor

        Exit Sub
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Sub

    Private Sub FrmDisk_Activated(sender As Object, e As EventArgs) Handles Me.Activated
        On Error GoTo Err

        Refresh()

        Exit Sub
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Sub

    Private Sub FrmDisk_Closing(sender As Object, e As CancelEventArgs) Handles Me.Closing
        On Error GoTo Err

        Application.UseWaitCursor = False

        Exit Sub
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Sub
End Class
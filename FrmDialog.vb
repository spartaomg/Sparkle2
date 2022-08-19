Public Class FrmDialog
    Private Sub chkDontShow_CheckedChanged(sender As Object, e As EventArgs) Handles chkDontShow.CheckedChanged

        My.Settings.FrameworkDontShowDlg = chkDontShow.Checked
        My.Settings.Save()

    End Sub
End Class
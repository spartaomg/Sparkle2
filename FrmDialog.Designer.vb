<Global.Microsoft.VisualBasic.CompilerServices.DesignerGenerated()> _
Partial Class FrmDialog
    Inherits System.Windows.Forms.Form

    'Form overrides dispose to clean up the component list.
    <System.Diagnostics.DebuggerNonUserCode()> _
    Protected Overrides Sub Dispose(ByVal disposing As Boolean)
        Try
            If disposing AndAlso components IsNot Nothing Then
                components.Dispose()
            End If
        Finally
            MyBase.Dispose(disposing)
        End Try
    End Sub

    'Required by the Windows Form Designer
    Private components As System.ComponentModel.IContainer

    'NOTE: The following procedure is required by the Windows Form Designer
    'It can be modified using the Windows Form Designer.  
    'Do not modify it using the code editor.
    <System.Diagnostics.DebuggerStepThrough()> _
    Private Sub InitializeComponent()
        Me.lblFramework = New System.Windows.Forms.Label()
        Me.Button1 = New System.Windows.Forms.Button()
        Me.chkDontShow = New System.Windows.Forms.CheckBox()
        Me.SuspendLayout()
        '
        'lblFramework
        '
        Me.lblFramework.Location = New System.Drawing.Point(20, 9)
        Me.lblFramework.Name = "lblFramework"
        Me.lblFramework.Size = New System.Drawing.Size(268, 28)
        Me.lblFramework.TabIndex = 0
        Me.lblFramework.Text = "Sparkle requires .NET Framework version 4.8 or newer. Please update your PC."
        '
        'Button1
        '
        Me.Button1.DialogResult = System.Windows.Forms.DialogResult.OK
        Me.Button1.Location = New System.Drawing.Point(120, 72)
        Me.Button1.Name = "Button1"
        Me.Button1.Size = New System.Drawing.Size(80, 24)
        Me.Button1.TabIndex = 1
        Me.Button1.Text = "OK"
        Me.Button1.UseVisualStyleBackColor = True
        '
        'chkDontShow
        '
        Me.chkDontShow.AutoSize = True
        Me.chkDontShow.Location = New System.Drawing.Point(23, 43)
        Me.chkDontShow.Name = "chkDontShow"
        Me.chkDontShow.Size = New System.Drawing.Size(172, 17)
        Me.chkDontShow.TabIndex = 2
        Me.chkDontShow.Text = "Don't show this message again"
        Me.chkDontShow.UseVisualStyleBackColor = True
        '
        'FrmDialog
        '
        Me.AutoScaleDimensions = New System.Drawing.SizeF(6.0!, 13.0!)
        Me.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font
        Me.CancelButton = Me.Button1
        Me.ClientSize = New System.Drawing.Size(304, 105)
        Me.ControlBox = False
        Me.Controls.Add(Me.chkDontShow)
        Me.Controls.Add(Me.Button1)
        Me.Controls.Add(Me.lblFramework)
        Me.FormBorderStyle = System.Windows.Forms.FormBorderStyle.FixedDialog
        Me.MaximizeBox = False
        Me.MinimizeBox = False
        Me.Name = "FrmDialog"
        Me.ShowIcon = False
        Me.ShowInTaskbar = False
        Me.StartPosition = System.Windows.Forms.FormStartPosition.CenterScreen
        Me.Text = "Outdated .NET Framework version detected"
        Me.ResumeLayout(False)
        Me.PerformLayout()

    End Sub

    Friend WithEvents lblFramework As Label
    Friend WithEvents Button1 As Button
    Friend WithEvents chkDontShow As CheckBox
End Class

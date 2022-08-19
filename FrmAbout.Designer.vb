<Global.Microsoft.VisualBasic.CompilerServices.DesignerGenerated()> _
Partial Class FrmAbout
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
        Dim resources As System.ComponentModel.ComponentResourceManager = New System.ComponentModel.ComponentResourceManager(GetType(FrmAbout))
        Me.lblDescription = New System.Windows.Forms.Label()
        Me.lblMe = New System.Windows.Forms.Label()
        Me.PbxLogo = New System.Windows.Forms.PictureBox()
        Me.LblName = New System.Windows.Forms.Label()
        Me.LblVersion = New System.Windows.Forms.Label()
        CType(Me.PbxLogo, System.ComponentModel.ISupportInitialize).BeginInit()
        Me.SuspendLayout()
        '
        'lblDescription
        '
        Me.lblDescription.Location = New System.Drawing.Point(0, 70)
        Me.lblDescription.Name = "lblDescription"
        Me.lblDescription.Size = New System.Drawing.Size(300, 14)
        Me.lblDescription.TabIndex = 1
        Me.lblDescription.Text = "An IRQ Loader and Linking Solution for the Commodore 64"
        Me.lblDescription.TextAlign = System.Drawing.ContentAlignment.MiddleCenter
        '
        'lblMe
        '
        Me.lblMe.Location = New System.Drawing.Point(0, 97)
        Me.lblMe.Name = "lblMe"
        Me.lblMe.Size = New System.Drawing.Size(300, 13)
        Me.lblMe.TabIndex = 2
        Me.lblMe.Text = "by Sparta, 2019-2020"
        Me.lblMe.TextAlign = System.Drawing.ContentAlignment.MiddleCenter
        '
        'PbxLogo
        '
        Me.PbxLogo.BackColor = System.Drawing.SystemColors.ButtonFace
        Me.PbxLogo.BackgroundImage = CType(resources.GetObject("PbxLogo.BackgroundImage"), System.Drawing.Image)
        Me.PbxLogo.BackgroundImageLayout = System.Windows.Forms.ImageLayout.Zoom
        Me.PbxLogo.Location = New System.Drawing.Point(28, 16)
        Me.PbxLogo.Name = "PbxLogo"
        Me.PbxLogo.Size = New System.Drawing.Size(48, 48)
        Me.PbxLogo.TabIndex = 4
        Me.PbxLogo.TabStop = False
        '
        'LblName
        '
        Me.LblName.AutoSize = True
        Me.LblName.Font = New System.Drawing.Font("Microsoft Sans Serif", 27.75!, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, CType(0, Byte))
        Me.LblName.Location = New System.Drawing.Point(76, 19)
        Me.LblName.Name = "LblName"
        Me.LblName.Size = New System.Drawing.Size(198, 42)
        Me.LblName.TabIndex = 5
        Me.LblName.Text = "SPARKLE"
        '
        'LblVersion
        '
        Me.LblVersion.Location = New System.Drawing.Point(0, 121)
        Me.LblVersion.Name = "LblVersion"
        Me.LblVersion.Size = New System.Drawing.Size(300, 13)
        Me.LblVersion.TabIndex = 6
        Me.LblVersion.Text = "Version:"
        Me.LblVersion.TextAlign = System.Drawing.ContentAlignment.MiddleCenter
        '
        'FrmAbout
        '
        Me.AutoScaleDimensions = New System.Drawing.SizeF(6.0!, 13.0!)
        Me.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font
        Me.BackColor = System.Drawing.SystemColors.ButtonFace
        Me.ClientSize = New System.Drawing.Size(300, 160)
        Me.ControlBox = False
        Me.Controls.Add(Me.LblVersion)
        Me.Controls.Add(Me.PbxLogo)
        Me.Controls.Add(Me.lblMe)
        Me.Controls.Add(Me.lblDescription)
        Me.Controls.Add(Me.LblName)
        Me.FormBorderStyle = System.Windows.Forms.FormBorderStyle.None
        Me.MaximizeBox = False
        Me.MinimizeBox = False
        Me.Name = "FrmAbout"
        Me.ShowIcon = False
        Me.ShowInTaskbar = False
        Me.StartPosition = System.Windows.Forms.FormStartPosition.CenterScreen
        Me.Text = "FrmAbout"
        CType(Me.PbxLogo, System.ComponentModel.ISupportInitialize).EndInit()
        Me.ResumeLayout(False)
        Me.PerformLayout()

    End Sub
    Friend WithEvents lblDescription As Label
    Friend WithEvents lblMe As Label
    Friend WithEvents PbxLogo As PictureBox
    Friend WithEvents LblName As Label
    Friend WithEvents LblVersion As Label
End Class

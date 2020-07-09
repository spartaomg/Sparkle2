<Global.Microsoft.VisualBasic.CompilerServices.DesignerGenerated()>
Partial Class FrmDisk
	Inherits System.Windows.Forms.Form

	'Form overrides dispose to clean up the component list.
	<System.Diagnostics.DebuggerNonUserCode()>
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
	<System.Diagnostics.DebuggerStepThrough()>
	Private Sub InitializeComponent()
		Dim resources As System.ComponentModel.ComponentResourceManager = New System.ComponentModel.ComponentResourceManager(GetType(FrmDisk))
		Me.Lbl = New System.Windows.Forms.Label()
		Me.Pbx1 = New System.Windows.Forms.PictureBox()
		Me.Pbx2 = New System.Windows.Forms.PictureBox()
		Me.Pbx3 = New System.Windows.Forms.PictureBox()
		Me.Pbx4 = New System.Windows.Forms.PictureBox()
		CType(Me.Pbx1, System.ComponentModel.ISupportInitialize).BeginInit()
		CType(Me.Pbx2, System.ComponentModel.ISupportInitialize).BeginInit()
		CType(Me.Pbx3, System.ComponentModel.ISupportInitialize).BeginInit()
		CType(Me.Pbx4, System.ComponentModel.ISupportInitialize).BeginInit()
		Me.SuspendLayout()
		'
		'Lbl
		'
		Me.Lbl.AutoSize = True
		Me.Lbl.Font = New System.Drawing.Font("Microsoft Sans Serif", 14.25!, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, CType(0, Byte))
		Me.Lbl.Location = New System.Drawing.Point(58, 23)
		Me.Lbl.Name = "Lbl"
		Me.Lbl.Size = New System.Drawing.Size(177, 24)
		Me.Lbl.TabIndex = 0
		Me.Lbl.Text = "Sparkle is working..."
		'
		'Pbx1
		'
		Me.Pbx1.BackgroundImage = CType(resources.GetObject("Pbx1.BackgroundImage"), System.Drawing.Image)
		Me.Pbx1.Location = New System.Drawing.Point(8, 12)
		Me.Pbx1.Name = "Pbx1"
		Me.Pbx1.Size = New System.Drawing.Size(48, 48)
		Me.Pbx1.TabIndex = 1
		Me.Pbx1.TabStop = False
		'
		'Pbx2
		'
		Me.Pbx2.BackgroundImage = CType(resources.GetObject("Pbx2.BackgroundImage"), System.Drawing.Image)
		Me.Pbx2.Location = New System.Drawing.Point(8, 12)
		Me.Pbx2.Name = "Pbx2"
		Me.Pbx2.Size = New System.Drawing.Size(48, 48)
		Me.Pbx2.TabIndex = 2
		Me.Pbx2.TabStop = False
		Me.Pbx2.Visible = False
		'
		'Pbx3
		'
		Me.Pbx3.BackgroundImage = CType(resources.GetObject("Pbx3.BackgroundImage"), System.Drawing.Image)
		Me.Pbx3.Location = New System.Drawing.Point(8, 12)
		Me.Pbx3.Name = "Pbx3"
		Me.Pbx3.Size = New System.Drawing.Size(48, 48)
		Me.Pbx3.TabIndex = 3
		Me.Pbx3.TabStop = False
		Me.Pbx3.Visible = False
		'
		'Pbx4
		'
		Me.Pbx4.BackgroundImage = CType(resources.GetObject("Pbx4.BackgroundImage"), System.Drawing.Image)
		Me.Pbx4.Location = New System.Drawing.Point(8, 12)
		Me.Pbx4.Name = "Pbx4"
		Me.Pbx4.Size = New System.Drawing.Size(48, 48)
		Me.Pbx4.TabIndex = 4
		Me.Pbx4.TabStop = False
		Me.Pbx4.Visible = False
		'
		'FrmDisk
		'
		Me.AutoScaleDimensions = New System.Drawing.SizeF(6.0!, 13.0!)
		Me.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font
		Me.ClientSize = New System.Drawing.Size(242, 72)
		Me.Controls.Add(Me.Pbx1)
		Me.Controls.Add(Me.Lbl)
		Me.Controls.Add(Me.Pbx4)
		Me.Controls.Add(Me.Pbx3)
		Me.Controls.Add(Me.Pbx2)
		Me.FormBorderStyle = System.Windows.Forms.FormBorderStyle.None
		Me.Icon = CType(resources.GetObject("$this.Icon"), System.Drawing.Icon)
		Me.Name = "FrmDisk"
		Me.ShowInTaskbar = False
		Me.StartPosition = System.Windows.Forms.FormStartPosition.CenterScreen
		CType(Me.Pbx1, System.ComponentModel.ISupportInitialize).EndInit()
		CType(Me.Pbx2, System.ComponentModel.ISupportInitialize).EndInit()
		CType(Me.Pbx3, System.ComponentModel.ISupportInitialize).EndInit()
		CType(Me.Pbx4, System.ComponentModel.ISupportInitialize).EndInit()
		Me.ResumeLayout(False)
		Me.PerformLayout()

	End Sub

	Friend WithEvents Lbl As Label
	Friend WithEvents Pbx1 As PictureBox
	Friend WithEvents Pbx2 As PictureBox
	Friend WithEvents Pbx3 As PictureBox
	Friend WithEvents Pbx4 As PictureBox
End Class

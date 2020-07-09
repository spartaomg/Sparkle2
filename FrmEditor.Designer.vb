<Global.Microsoft.VisualBasic.CompilerServices.DesignerGenerated()> _
Partial Class FrmEditor
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
		Dim resources As System.ComponentModel.ComponentResourceManager = New System.ComponentModel.ComponentResourceManager(GetType(FrmEditor))
		Me.ChkToolTips = New System.Windows.Forms.CheckBox()
		Me.ChkExpand = New System.Windows.Forms.CheckBox()
		Me.BtnEntryDown = New System.Windows.Forms.Button()
		Me.BtnEntryUp = New System.Windows.Forms.Button()
		Me.BtnFileDown = New System.Windows.Forms.Button()
		Me.BtnFileUp = New System.Windows.Forms.Button()
		Me.txtEdit = New System.Windows.Forms.TextBox()
		Me.Label10 = New System.Windows.Forms.Label()
		Me.BtnNew = New System.Windows.Forms.Button()
		Me.BtnCancel = New System.Windows.Forms.Button()
		Me.BtnOK = New System.Windows.Forms.Button()
		Me.BtnSave = New System.Windows.Forms.Button()
		Me.BtnLoad = New System.Windows.Forms.Button()
		Me.TV = New System.Windows.Forms.TreeView()
		Me.strip = New System.Windows.Forms.StatusStrip()
		Me.tssLabel = New System.Windows.Forms.ToolStripStatusLabel()
		Me.TssDisk = New System.Windows.Forms.ToolStripStatusLabel()
		Me.PnlPath = New System.Windows.Forms.Panel()
		Me.OptFullPaths = New System.Windows.Forms.RadioButton()
		Me.OptRelativePaths = New System.Windows.Forms.RadioButton()
		Me.Label1 = New System.Windows.Forms.Label()
		Me.ChkSize = New System.Windows.Forms.CheckBox()
		Me.strip.SuspendLayout()
		Me.PnlPath.SuspendLayout()
		Me.SuspendLayout()
		'
		'ChkToolTips
		'
		Me.ChkToolTips.AutoSize = True
		Me.ChkToolTips.Location = New System.Drawing.Point(674, 263)
		Me.ChkToolTips.Name = "ChkToolTips"
		Me.ChkToolTips.Size = New System.Drawing.Size(97, 17)
		Me.ChkToolTips.TabIndex = 124
		Me.ChkToolTips.Text = "Show ToolTips"
		Me.ChkToolTips.UseVisualStyleBackColor = True
		'
		'ChkExpand
		'
		Me.ChkExpand.AutoSize = True
		Me.ChkExpand.Location = New System.Drawing.Point(674, 240)
		Me.ChkExpand.Name = "ChkExpand"
		Me.ChkExpand.Size = New System.Drawing.Size(88, 17)
		Me.ChkExpand.TabIndex = 123
		Me.ChkExpand.Text = "Show Details"
		Me.ChkExpand.UseVisualStyleBackColor = True
		'
		'BtnEntryDown
		'
		Me.BtnEntryDown.Location = New System.Drawing.Point(675, 174)
		Me.BtnEntryDown.Name = "BtnEntryDown"
		Me.BtnEntryDown.Size = New System.Drawing.Size(96, 23)
		Me.BtnEntryDown.TabIndex = 122
		Me.BtnEntryDown.Text = "Move Down"
		Me.BtnEntryDown.UseVisualStyleBackColor = True
		'
		'BtnEntryUp
		'
		Me.BtnEntryUp.Location = New System.Drawing.Point(675, 145)
		Me.BtnEntryUp.Name = "BtnEntryUp"
		Me.BtnEntryUp.Size = New System.Drawing.Size(96, 23)
		Me.BtnEntryUp.TabIndex = 121
		Me.BtnEntryUp.Text = "Move Up"
		Me.BtnEntryUp.UseVisualStyleBackColor = True
		'
		'BtnFileDown
		'
		Me.BtnFileDown.Location = New System.Drawing.Point(675, 173)
		Me.BtnFileDown.Name = "BtnFileDown"
		Me.BtnFileDown.Size = New System.Drawing.Size(96, 23)
		Me.BtnFileDown.TabIndex = 120
		Me.BtnFileDown.Text = "Move File Down"
		Me.BtnFileDown.UseVisualStyleBackColor = True
		Me.BtnFileDown.Visible = False
		'
		'BtnFileUp
		'
		Me.BtnFileUp.Location = New System.Drawing.Point(675, 144)
		Me.BtnFileUp.Name = "BtnFileUp"
		Me.BtnFileUp.Size = New System.Drawing.Size(96, 23)
		Me.BtnFileUp.TabIndex = 119
		Me.BtnFileUp.Text = "Move File Up"
		Me.BtnFileUp.UseVisualStyleBackColor = True
		Me.BtnFileUp.Visible = False
		'
		'txtEdit
		'
		Me.txtEdit.BackColor = System.Drawing.SystemColors.Window
		Me.txtEdit.BorderStyle = System.Windows.Forms.BorderStyle.None
		Me.txtEdit.Font = New System.Drawing.Font("Consolas", 9.75!, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, CType(0, Byte))
		Me.txtEdit.Location = New System.Drawing.Point(674, 481)
		Me.txtEdit.Name = "txtEdit"
		Me.txtEdit.Size = New System.Drawing.Size(28, 16)
		Me.txtEdit.TabIndex = 112
		Me.txtEdit.Visible = False
		'
		'Label10
		'
		Me.Label10.AutoSize = True
		Me.Label10.Location = New System.Drawing.Point(10, 4)
		Me.Label10.Name = "Label10"
		Me.Label10.Size = New System.Drawing.Size(84, 13)
		Me.Label10.TabIndex = 118
		Me.Label10.Text = "Demo Structure:"
		'
		'BtnNew
		'
		Me.BtnNew.Location = New System.Drawing.Point(675, 20)
		Me.BtnNew.Name = "BtnNew"
		Me.BtnNew.Size = New System.Drawing.Size(96, 26)
		Me.BtnNew.TabIndex = 113
		Me.BtnNew.Text = "New Script"
		Me.BtnNew.UseVisualStyleBackColor = True
		'
		'BtnCancel
		'
		Me.BtnCancel.DialogResult = System.Windows.Forms.DialogResult.Cancel
		Me.BtnCancel.Location = New System.Drawing.Point(675, 535)
		Me.BtnCancel.Name = "BtnCancel"
		Me.BtnCancel.Size = New System.Drawing.Size(96, 26)
		Me.BtnCancel.TabIndex = 117
		Me.BtnCancel.Text = "Close"
		Me.BtnCancel.UseVisualStyleBackColor = True
		'
		'BtnOK
		'
		Me.BtnOK.AccessibleRole = System.Windows.Forms.AccessibleRole.None
		Me.BtnOK.Location = New System.Drawing.Point(675, 503)
		Me.BtnOK.Name = "BtnOK"
		Me.BtnOK.Size = New System.Drawing.Size(96, 26)
		Me.BtnOK.TabIndex = 116
		Me.BtnOK.Text = "Close && Build"
		Me.BtnOK.UseVisualStyleBackColor = True
		'
		'BtnSave
		'
		Me.BtnSave.Location = New System.Drawing.Point(675, 84)
		Me.BtnSave.Name = "BtnSave"
		Me.BtnSave.Size = New System.Drawing.Size(96, 26)
		Me.BtnSave.TabIndex = 115
		Me.BtnSave.Text = "Save Script"
		Me.BtnSave.UseVisualStyleBackColor = True
		'
		'BtnLoad
		'
		Me.BtnLoad.Location = New System.Drawing.Point(675, 52)
		Me.BtnLoad.Name = "BtnLoad"
		Me.BtnLoad.Size = New System.Drawing.Size(96, 26)
		Me.BtnLoad.TabIndex = 114
		Me.BtnLoad.Text = "Load Script"
		Me.BtnLoad.UseVisualStyleBackColor = True
		'
		'TV
		'
		Me.TV.Font = New System.Drawing.Font("Microsoft Sans Serif", 9.75!, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, CType(0, Byte))
		Me.TV.Indent = 19
		Me.TV.Location = New System.Drawing.Point(10, 21)
		Me.TV.Name = "TV"
		Me.TV.Size = New System.Drawing.Size(646, 542)
		Me.TV.TabIndex = 111
		'
		'strip
		'
		Me.strip.ImageScalingSize = New System.Drawing.Size(20, 20)
		Me.strip.Items.AddRange(New System.Windows.Forms.ToolStripItem() {Me.tssLabel, Me.TssDisk})
		Me.strip.Location = New System.Drawing.Point(0, 579)
		Me.strip.Name = "strip"
		Me.strip.Size = New System.Drawing.Size(784, 22)
		Me.strip.SizingGrip = False
		Me.strip.TabIndex = 126
		Me.strip.Text = "StatusStrip1"
		'
		'tssLabel
		'
		Me.tssLabel.Name = "tssLabel"
		Me.tssLabel.Size = New System.Drawing.Size(647, 17)
		Me.tssLabel.Spring = True
		Me.tssLabel.Text = "Script: (New Script)"
		Me.tssLabel.TextAlign = System.Drawing.ContentAlignment.MiddleLeft
		'
		'TssDisk
		'
		Me.TssDisk.DisplayStyle = System.Windows.Forms.ToolStripItemDisplayStyle.Text
		Me.TssDisk.Name = "TssDisk"
		Me.TssDisk.Size = New System.Drawing.Size(122, 17)
		Me.TssDisk.Text = "Disk 1: 664 blocks free"
		'
		'PnlPath
		'
		Me.PnlPath.Controls.Add(Me.OptFullPaths)
		Me.PnlPath.Controls.Add(Me.OptRelativePaths)
		Me.PnlPath.Controls.Add(Me.Label1)
		Me.PnlPath.Location = New System.Drawing.Point(666, 294)
		Me.PnlPath.Name = "PnlPath"
		Me.PnlPath.Size = New System.Drawing.Size(108, 71)
		Me.PnlPath.TabIndex = 127
		'
		'OptFullPaths
		'
		Me.OptFullPaths.AutoSize = True
		Me.OptFullPaths.Location = New System.Drawing.Point(9, 44)
		Me.OptFullPaths.Name = "OptFullPaths"
		Me.OptFullPaths.Size = New System.Drawing.Size(41, 17)
		Me.OptFullPaths.TabIndex = 2
		Me.OptFullPaths.TabStop = True
		Me.OptFullPaths.Text = "Full"
		Me.OptFullPaths.UseVisualStyleBackColor = True
		'
		'OptRelativePaths
		'
		Me.OptRelativePaths.AutoSize = True
		Me.OptRelativePaths.Location = New System.Drawing.Point(8, 21)
		Me.OptRelativePaths.Name = "OptRelativePaths"
		Me.OptRelativePaths.Size = New System.Drawing.Size(64, 17)
		Me.OptRelativePaths.TabIndex = 1
		Me.OptRelativePaths.TabStop = True
		Me.OptRelativePaths.Text = "Relative"
		Me.OptRelativePaths.TextAlign = System.Drawing.ContentAlignment.MiddleCenter
		Me.OptRelativePaths.UseVisualStyleBackColor = True
		'
		'Label1
		'
		Me.Label1.AutoSize = True
		Me.Label1.Font = New System.Drawing.Font("Microsoft Sans Serif", 8.25!, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, CType(0, Byte))
		Me.Label1.Location = New System.Drawing.Point(6, 5)
		Me.Label1.Name = "Label1"
		Me.Label1.Size = New System.Drawing.Size(67, 13)
		Me.Label1.TabIndex = 0
		Me.Label1.Text = "File Paths:"
		'
		'ChkSize
		'
		Me.ChkSize.AutoSize = True
		Me.ChkSize.Location = New System.Drawing.Point(674, 217)
		Me.ChkSize.Name = "ChkSize"
		Me.ChkSize.Size = New System.Drawing.Size(91, 17)
		Me.ChkSize.TabIndex = 128
		Me.ChkSize.Text = "Autocalc Size"
		Me.ChkSize.UseVisualStyleBackColor = True
		'
		'FrmEditor
		'
		Me.AutoScaleDimensions = New System.Drawing.SizeF(6.0!, 13.0!)
		Me.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font
		Me.ClientSize = New System.Drawing.Size(784, 601)
		Me.Controls.Add(Me.ChkSize)
		Me.Controls.Add(Me.PnlPath)
		Me.Controls.Add(Me.strip)
		Me.Controls.Add(Me.ChkToolTips)
		Me.Controls.Add(Me.ChkExpand)
		Me.Controls.Add(Me.BtnEntryDown)
		Me.Controls.Add(Me.BtnEntryUp)
		Me.Controls.Add(Me.BtnFileDown)
		Me.Controls.Add(Me.BtnFileUp)
		Me.Controls.Add(Me.txtEdit)
		Me.Controls.Add(Me.Label10)
		Me.Controls.Add(Me.BtnNew)
		Me.Controls.Add(Me.BtnCancel)
		Me.Controls.Add(Me.BtnOK)
		Me.Controls.Add(Me.BtnSave)
		Me.Controls.Add(Me.BtnLoad)
		Me.Controls.Add(Me.TV)
		Me.Icon = CType(resources.GetObject("$this.Icon"), System.Drawing.Icon)
		Me.KeyPreview = True
		Me.MinimizeBox = False
		Me.MinimumSize = New System.Drawing.Size(800, 640)
		Me.Name = "FrmEditor"
		Me.StartPosition = System.Windows.Forms.FormStartPosition.CenterScreen
		Me.Text = "Script Editor"
		Me.strip.ResumeLayout(False)
		Me.strip.PerformLayout()
		Me.PnlPath.ResumeLayout(False)
		Me.PnlPath.PerformLayout()
		Me.ResumeLayout(False)
		Me.PerformLayout()

	End Sub
	Friend WithEvents ChkToolTips As CheckBox
	Friend WithEvents ChkExpand As CheckBox
	Friend WithEvents BtnEntryDown As Button
	Friend WithEvents BtnEntryUp As Button
	Friend WithEvents BtnFileDown As Button
	Friend WithEvents BtnFileUp As Button
	Friend WithEvents txtEdit As TextBox
	Friend WithEvents Label10 As Label
	Friend WithEvents BtnNew As Button
	Friend WithEvents BtnCancel As Button
	Friend WithEvents BtnOK As Button
	Friend WithEvents BtnSave As Button
	Friend WithEvents BtnLoad As Button
	Friend WithEvents TV As TreeView
	Friend WithEvents strip As StatusStrip
	Friend WithEvents tssLabel As ToolStripStatusLabel
	Friend WithEvents TssDisk As ToolStripStatusLabel
	Friend WithEvents PnlPath As Panel
	Friend WithEvents OptFullPaths As RadioButton
	Friend WithEvents OptRelativePaths As RadioButton
	Friend WithEvents Label1 As Label
	Friend WithEvents ChkSize As CheckBox
End Class

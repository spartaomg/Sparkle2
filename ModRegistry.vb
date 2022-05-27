Imports System.IO
Imports Microsoft.Win32
Imports System.Text
Imports System.Runtime.CompilerServices

Friend Module ModRegistry

    Private ReadOnly DotNet45ReleaseKey As Integer = 378389
    Private ReadOnly DotNet48ReleaseKey As Integer = 528040

    Private ReadOnly OMGFolder As String = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData) + "\" + My.Application.Info.CompanyName
    Private ReadOnly SparkleFolder As String = OMGFolder + "\Sparkle"
    Private ReadOnly ConfigFile As String = SparkleFolder + "\Sparkle.config"
    Private ReadOnly CurrentFolder As String = My.Application.Info.DirectoryPath
    Private DefaultFolder As String = "<*>"   'Invalid file name characters to make sure we will not find them in SYSTEM PATH

    Private Sub CheckDefaultFolder()

        Try
            If Not Directory.Exists(OMGFolder) Then
                Directory.CreateDirectory(OMGFolder)
                'MsgBox("Directory.CreateDirectory(OMGFolder)")
            Else
                'MsgBox("OMG folder exists")
            End If

            If Not Directory.Exists(SparkleFolder) Then
                Directory.CreateDirectory(SparkleFolder)
                'MsgBox("Directory.CreateDirectory(SparkleFolder)")
            Else
                'MsgBox("Sparkle folder exists")
            End If

            If File.Exists(ConfigFile) Then
                DefaultFolder = File.ReadAllText(ConfigFile)
                'MsgBox("DefaultFolder = File.ReadAllText(ConfigFile)")
            Else
                'File.Create(ConfigFile).Close()
                'MsgBox("Config file does not exist")
            End If

        Catch Ex As Exception
            MsgBox(Ex.Message, vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")
        End Try

        If DefaultFolder = "" Then
            DefaultFolder = "<*>"
        End If

    End Sub

    Private Function GetPath() As String

        Try
            GetPath = Environment.GetEnvironmentVariable("PATH", EnvironmentVariableTarget.User)
        Catch ex As ArgumentException
            MsgBox(ex.Message, vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")
            GetPath = ""
        End Try

        'Make sure GetPath has a value
        If GetPath Is Nothing Then GetPath = ""

    End Function

    Private Sub SetPath(P As String)

        Try
            Environment.SetEnvironmentVariable("PATH", P, EnvironmentVariableTarget.User)
        Catch ex As ArgumentException
            MsgBox(ex.Message, vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")
        End Try

    End Sub

    Public Sub UpdatePath()
        If DoOnErr  then On Error GoTo Err

        CheckDefaultFolder()

        If DefaultFolder <> CurrentFolder Then

            'Get USER PATH and split it into substrings
            Dim PathEntry() As String = GetPath.Split(";")

            'Remove Default Folder and Current Folder substrings and rebuild USER PATH string
            Dim S As String = CurrentFolder
            For C As Integer = 0 To PathEntry.Length - 1
                If (PathEntry(C) <> "") And (PathEntry(C) <> DefaultFolder) And (PathEntry(C) <> CurrentFolder) Then
                    S += ";" + PathEntry(C)
                End If
            Next

            'Update Default Folder Value in Config File with Current Folder
            File.WriteAllText(ConfigFile, CurrentFolder)

            'Save updated SYSTEM PATH for current user
            SetPath(S)
        End If

        Exit Sub
Err:
        'ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Sub

    Public Sub AssociateSLS()
        If DoOnErr  then On Error GoTo Err

        If My.Computer.Registry.ClassesRoot.OpenSubKey("Sparkle Loader Script\shell\open\command", True) Is Nothing Then
            If MsgBox("Do you want to associate the .sls file extension with Sparkle?", vbYesNo + vbQuestion, "Sparkle Admin Mode") = vbYes Then
                My.Computer.Registry.ClassesRoot.CreateSubKey(".sls").SetValue("", "Sparkle Loader Script", Microsoft.Win32.RegistryValueKind.String)
                My.Computer.Registry.ClassesRoot.CreateSubKey("Sparkle Loader Script\shell\open\command").SetValue("", Application.ExecutablePath & " ""%l"" ", Microsoft.Win32.RegistryValueKind.String)

                Using SK1 As RegistryKey = RegistryKey.OpenBaseKey(RegistryHive.CurrentUser, RegistryView.Registry32).OpenSubKey("Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.sls")
                    If SK1 IsNot Nothing Then
                        My.Computer.Registry.CurrentUser.DeleteSubKeyTree("Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.sls")
                        SK1.Close()
                    End If
                End Using
            Else
                Exit Sub
            End If
        Else
            If MsgBox("The .sls file extension is already associated with Sparkle." + vbNewLine + vbNewLine + "Do you want to update it?", vbYesNo + vbQuestion, "Sparkle Admin Mode") = vbYes Then
                My.Computer.Registry.ClassesRoot.CreateSubKey(".sls").SetValue("", "Sparkle Loader Script", Microsoft.Win32.RegistryValueKind.String)
                My.Computer.Registry.ClassesRoot.CreateSubKey("Sparkle Loader Script\shell\open\command").SetValue("", Application.ExecutablePath & " ""%l"" ", Microsoft.Win32.RegistryValueKind.String)

                Using SK2 As RegistryKey = RegistryKey.OpenBaseKey(RegistryHive.CurrentUser, RegistryView.Registry32).OpenSubKey("Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.sls")
                    If SK2 IsNot Nothing Then
                        My.Computer.Registry.CurrentUser.DeleteSubKeyTree("Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.sls")
                        SK2.Close()
                    End If
                End Using
            Else
                Exit Sub
            End If
        End If

        MsgBox("The .sls file extension has been successfully associated with Sparkle!", vbOKOnly + vbInformation, "Sparkle Admin Mode")

        Exit Sub
Err:
        ErrCode = Err.Number
        MsgBox("Error during creating .sls file association with Sparkle" + vbNewLine + vbNewLine + ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Sub

    Public Sub DeleteAssociation()
        If DoOnErr  then On Error GoTo Err

        If MsgBox("Do you want to delete the .sls file association with Sparkle?", vbYesNo + vbQuestion, "Sparkle Admin Mode") = vbYes Then

            Using SK1 As RegistryKey = RegistryKey.OpenBaseKey(RegistryHive.ClassesRoot, RegistryView.Registry32).OpenSubKey("Sparkle Loader Script\shell\open\command")
                If SK1 IsNot Nothing Then
                    My.Computer.Registry.ClassesRoot.DeleteSubKeyTree("Sparkle Loader Script")
                    SK1.Close()
                End If
            End Using

            Using SK2 As RegistryKey = RegistryKey.OpenBaseKey(RegistryHive.ClassesRoot, RegistryView.Registry32).OpenSubKey(".sls")
                If SK2 IsNot Nothing Then
                    My.Computer.Registry.ClassesRoot.DeleteSubKeyTree(".sls")
                    SK2.Close()
                End If
            End Using

            Using SK3 As RegistryKey = RegistryKey.OpenBaseKey(RegistryHive.CurrentUser, RegistryView.Registry32).OpenSubKey("Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.sls")
                If SK3 IsNot Nothing Then
                    My.Computer.Registry.CurrentUser.DeleteSubKeyTree("Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.sls")
                    SK3.Close()
                End If
            End Using

            MsgBox("The .sls file extension is no longer associated with Sparkle.", vbOKOnly + vbInformation, "Sparkle Admin Mode")
        End If

        Exit Sub
Err:
        ErrCode = Err.Number
        MsgBox("Error during deleting .sls file association with Sparkle" + vbNewLine + vbNewLine + ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Sub

    Public Function DotNetVersion() As Boolean
        If DoOnErr  then On Error GoTo Err

        Const SubKey As String = "SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\"

        Using NDPKey As RegistryKey = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, RegistryView.Registry32).OpenSubKey(SubKey)
            If NDPKey IsNot Nothing AndAlso NDPKey.GetValue("Release") IsNot Nothing Then
                DotNetVersion = CheckFor48PlusVersion(NDPKey.GetValue("Release"))
            Else
                DotNetVersion = False
            End If
        End Using

        Exit Function
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Function

    'Checking the version using >= will enable forward compatibility.
    Private Function CheckFor48PlusVersion(releaseKey As Integer) As Boolean
        If DoOnErr Then On Error GoTo Err

        If releaseKey >= DotNet48ReleaseKey Then    'Minimum releaseKey for .Net 4.8: 528040 (requires at least Windows 7 SP1)
            CheckFor48PlusVersion = True
        Else
            CheckFor48PlusVersion = False
        End If

        Exit Function
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Function

End Module

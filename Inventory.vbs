' Inventory.vbs - Revison 0001

Option Explicit

' Force to run in cscript, if run from wscript parse arguments, rerun from cscript
Sub forceCScriptExecution
    Dim Arg, Str
    If Not LCase( Right( WScript.FullName, 12 ) ) = "\cscript.exe" Then
        For Each Arg In WScript.Arguments
            If InStr( Arg, " " ) Then Arg = """" & Arg & """"
            Str = Str & " " & Arg
        Next
        CreateObject( "WScript.Shell" ).Run "cscript //nologo """ & WScript.ScriptFullName & """ " & Str
        WScript.Quit
    End If
End Sub
forceCScriptExecution

Dim strFilePath, strFileUpdPath, objFSO, objWShell, objFullScript, objFile, objFileUpd, objTextFileUpd, strDocDir
Dim objRootDSE, strDNSDomain, strFullScript, strFullPath, strFilter, strQuery, adoRecordset, adoConnection, adoCommand
Dim strComputerDN, objShell, lngBiasKey, lngBias
Dim objDate, dtmPwdLastSet, k, WshDoInventory, arrayTarget, strTarget
Dim intDays, intODays, objComputer, ForReading
Dim intTotal, intOrphaned, intInactive, intActive
Dim arrOutput, strOutLine, strActiveList, strComputerName, intFirstSplit, intSecondSplit, intDiffSplit
Dim objRegExEx, objFSOEx, objFileEx, objRegExSql, objFSOSql, objFileSql
On Error Resume Next

Function Integer8Date(objDate, lngBias)
    ' Function to convert Integer8 (64-bit) value to a date, adjusted for
    ' time zone bias.
    Dim lngAdjust, lngDate, lngHigh, lngLow
    lngAdjust = lngBias
    lngHigh = objDate.HighPart
    lngLow = objDate.LowPart
    ' Account for bug in IADsLargeInteger property methods.
    If (lngHigh = 0) And (lngLow = 0) Then
        lngAdjust = 0
    End If
    lngDate = #1/1/1601# + (((lngHigh * (2 ^ 32)) + lngLow) / 600000000 - lngAdjust) / 1440
    Integer8Date = CDate(lngDate)
End Function

' Specify the minimum number of days since the password was last set for
' the computer account to be considered inactive (intDays) and orphaned (intODays)
intDays = 90
intODays = 1095

' We'll be doing work on the filesystem and we'll need a shell
Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objWShell = CreateObject("Wscript.Shell")

'Determine absolute paths
strFullScript = Wscript.ScriptFullName
Set objFullScript = objFSO.GetFile(strFullScript)
strFullPath = objFSO.GetParentFolderName(objFullScript)

' Specify the log files. These files will be created if they do not
' exist. Otherwise, the program will append to the files.
strFilePath = strFullPath & "\Reports\ComputerAccounts.log"
strFileUpdPath = strFullPath & "\Reports\NeedsUpdate.txt"
strDocDir = strFullPath & "\Reports\"

' Delete existing log files
If objFSO.FileExists(strFilePath) Then
    objFSO.DeleteFile(strFilePath)
    Wscript.Echo "Removed existing " & strFilePath &"."
End If

If objFSO.FileExists(strFileUpdPath) Then
    objFSO.DeleteFile(strFileUpdPath)
    Wscript.Echo "Removed existing " & strFileUpdPath &"."
End If

' Open the log file for write access. Append to this file.
Set objFile = objFSO.OpenTextFile(strFilePath, 8, True, 0)
If (Err.Number <> 0) Then
    On Error GoTo 0
    Wscript.Echo "File " & strFilePath & " cannot be opened"
    Set objFSO = Nothing
    Wscript.Quit
End If
On Error GoTo 0

' Obtain local time zone bias from machine registry.
Set objShell = CreateObject("Wscript.Shell")
lngBiasKey = objShell.RegRead("HKLM\System\CurrentControlSet\Control\" & "TimeZoneInformation\ActiveTimeBias")
If (UCase(TypeName(lngBiasKey)) = "LONG") Then
    lngBias = lngBiasKey
ElseIf (UCase(TypeName(lngBiasKey)) = "VARIANT()") Then
    lngBias = 0
    For k = 0 To UBound(lngBiasKey)
        lngBias = lngBias + (lngBiasKey(k) * 256^k)
    Next
End If

' Use ADO to search the domain for all computers.
Set adoConnection = CreateObject("ADODB.Connection")
Set adoCommand = CreateObject("ADODB.Command")
adoConnection.Provider = "ADsDSOOBject"
adoConnection.Open "Active Directory Provider"
Set adoCommand.ActiveConnection = adoConnection

' Determine the DNS domain from the RootDSE object.
Set objRootDSE = GetObject("LDAP://RootDSE")
strDNSDomain = objRootDSE.Get("DefaultNamingContext")

' Filter to retrieve all computer objects.
strFilter = "(objectCategory=computer)"

' Retrieve Distinguished Name and date password last set.
strQuery = "<LDAP://" & strDNSDomain & ">;" & strFilter & ";distinguishedName,pwdLastSet;subtree"

adoCommand.CommandText = strQuery
adoCommand.Properties("Page Size") = 100
adoCommand.Properties("Timeout") = 30
adoCommand.Properties("Cache Results") = False

' Write information to log file.
objFile.WriteLine "Search for Inactive Computer Accounts"
objFile.WriteLine "Start: " & Now
objFile.WriteLine "Base of search: " & strDNSDomain
objFile.WriteLine "Log File: " & strFilePath
objFile.WriteLine "Orphaned if password not set in days: " & intODays
objFile.WriteLine "Inactive if password not set in days: " & intDays
objFile.WriteLine "----------------------------------------------"

' Initialize totals.
intTotal = 0
intInactive = 0
intOrphaned = 0

' Store output in array
Set arrOutput = CreateObject("System.Collections.ArrayList")

' Enumerate all computers and determine which are orphaned.
Set adoRecordset = adoCommand.Execute
Do Until adoRecordset.EOF
    strComputerDN = adoRecordset.Fields("distinguishedName").Value
    ' Escape any forward slash characters, "/", with the backslash
    ' escape character. All other characters that should be escaped are.
    strComputerDN = Replace(strComputerDN, "/", "\/")
    ' Determine date when password last set.
    Set objDate = adoRecordset.Fields("pwdLastSet").Value
    dtmPwdLastSet = Integer8Date(objDate, lngBias)
    ' Check if computer object orphaned.
    If (DateDiff("d", dtmPwdLastSet, Now) > intODays) Then
        intOrphaned = intOrphaned + 1
        intTotal = intTotal + 1
        arrOutput.Add "Orphaned: " & strComputerDN & " - password last set: " & dtmPwdLastSet
        On Error Resume Next
    End If
    adoRecordset.MoveNext
Loop
adoRecordset.Close

' Enumerate all computers and determine which are inactive.
Set adoRecordset = adoCommand.Execute
Do Until adoRecordset.EOF
    strComputerDN = adoRecordset.Fields("distinguishedName").Value
    ' Escape any forward slash characters, "/", with the backslash
    ' escape character. All other characters that should be escaped are.
    strComputerDN = Replace(strComputerDN, "/", "\/")
    ' Determine date when password last set.
    Set objDate = adoRecordset.Fields("pwdLastSet").Value
    dtmPwdLastSet = Integer8Date(objDate, lngBias)
    ' Check if computer object inactive.
    If (DateDiff("d", dtmPwdLastSet, Now) > intDays) Then
        If (DateDiff("d", dtmPwdLastSet, Now) < intODays) Then
            ' Computer object inactive.
            intInactive = intInactive + 1
            intTotal = intTotal + 1
            arrOutput.Add "Inactive: " & strComputerDN & " - password last set: " & dtmPwdLastSet
            On Error Resume Next
        End If
    End If
    adoRecordset.MoveNext
Loop
adoRecordset.Close

Set adoRecordset = adoCommand.Execute
Do Until adoRecordset.EOF
    strComputerDN = adoRecordset.Fields("distinguishedName").Value
    ' Escape any forward slash characters, "/", with the backslash
    ' escape character. All other characters that should be escaped are.
    strComputerDN = Replace(strComputerDN, "/", "\/")
    ' Determine date when password last set.
    Set objDate = adoRecordset.Fields("pwdLastSet").Value
    dtmPwdLastSet = Integer8Date(objDate, lngBias)
    ' Check if computer object inactive.
    If (DateDiff("d", dtmPwdLastSet, Now) < intDays) Then
        ' Computer object Active.
        intActive = intActive + 1
        intTotal = intTotal + 1
        arrOutput.Add "Active: " & strComputerDN & " - password last set: " & dtmPwdLastSet
        ' Write the report file to feed into network scanning tool
        intFirstSplit = InStr(strComputerDN, "CN=") + 3 ' We'll crop to that character
        intSecondSplit = InStr(intFirstSplit, strComputerDN, "=") - 3 ' Delete to the comma
        intDiffSplit = intSecondSplit - intFirstSplit
        strComputerName = mid(strComputerDN, intFirstSplit, intDiffSplit)
        strActiveList = strActiveList & strComputerName & " "
		On Error Resume Next
    End If
    adoRecordset.MoveNext
Loop
adoRecordset.Close

'Sort and write to output
arrOutput.Sort()
For each strOutLine in arrOutput
     objFile.WriteLine strOutLine
Next

' Write totals to log file.
objFile.WriteLine "Finished: " & Now
objFile.WriteLine "Total computer objects found:   " & intTotal
objFile.WriteLine "Acive:                          " & intActive
objFile.WriteLine "Inactive:                       " & intInactive
objFile.WriteLine "Orphaned:                       " & intOrphaned
objFile.WriteLine "----------------------------------------------"

' Display summary.
Wscript.Echo "Computer objects found:         " & intTotal
Wscript.Echo "Active:                         " & intActive
Wscript.Echo "Inactive:                       " & intInactive
Wscript.Echo "See log file: " & strFilePath

' Create the Update List
Set objFileUpd = objFSO.CreateTextFile(strUpdateReport)
Set objTextFileUpd = objFSO.OpenTextFile(strUpdateReport, 2, True)
objTextFileUpd.WriteLine("The following PCs need the listed software updated to the latest version:")
objTextFileUpd.Close

' Run the inventory on active accounts
strActiveList = RTrim(strActiveList)
arrayTarget=Split(strActiveList)
for each strTarget in arrayTarget
    If objFSO.FileExists(strDocDir &"\" &strTarget &".html") Then
        objFSO.DeleteFile(strDocDir &"\" & strTarget &".html")
    End If
    Wscript.Echo "Running inventory on " &strTarget &"."
    set WshDoInventory = CreateObject("WScript.Shell") 
    WshDoInventory.Run "cscript.exe " & strFullPath & "\util\runinv.vbs " & strTarget, 0, vbFalse
Next

' Clean up.
objFile.Close
adoConnection.Close
Set objFSO = Nothing
Set objFile = Nothing
Set objShell = Nothing
Set adoConnection = Nothing
Set adoCommand = Nothing
Set objRootDSE = Nothing
Set adoRecordset = Nothing
Set objComputer = Nothing
Set objDate = Nothing
Set objFSOEx = Nothing
Set objFSOSql = Nothing
Set objRegExEx = Nothing
Set objRegExSql = Nothing
Set objFileEx = Nothing
Set objFileSql = Nothing

Wscript.Echo "Done"




' Scan PC wrapprer

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

Dim objNetwork, objFSO, objShell, objDoInventory, objFile, objTextFile, objFileOpen, objFullScript, objNode, objNodeVals, objNodeOVers
Dim strTarget, strReport, strUpdateReport, strTempFolder, strHtmlReport, strFullScript
Dim strFullPath, strStylesheet, strLogo, strCl, strClH, strSoftwareList, strOpenFile, strAPIVer, strOSCaption, strOfficeVersion, strOSBuild
Dim xmlDoc, xmlDocVals, colNodes, colNodesVals, colNodesReg, colNodesFeatures, colNodesPatches, colNodeOS, colNodesOSPatch, colNodesOfficePatch, colOVers
Dim bPrintValues, bTestName, bTestVersion, bTestInclude, bTestExclude, bAvailable, bTestID, bTestOS, bHasGUITools, bHasGUI, bOSServer, bOSRT, bPostOSRelease
Dim objRegExp
Set objRegExp = New RegExp

Function IsOpen(strOpenFile)
    bAvailable = False
    Do
        On Error Resume Next
        Set objFileOpen = objFSO.OpenTextFile(strOpenFile, 8, False)
        If Err.Number = 70 Then
            wscript.Sleep 250
        ElseIf Err.Number <> 0 Then
            wscript.Echo "Something went wrong. Opening the file '" & strOpenFile & "' resulted in an unknown error: " & Err.Number & "."
            wscript.Quit 1
        Else
            bAvailable = True
            objFileOpen.Close
        End If
        Err.Clear
     Loop Until (bAvailable)
End Function

Set objNetwork = WScript.CreateObject("WScript.Network")
Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objShell = CreateObject("Wscript.Shell")

If WScript.Arguments.Count = 0 Then
    strTarget = objNetwork.ComputerName
ElseIf WScript.Arguments.Count > 1 Then
    wscript.Echo "Error, too many arguments!"
    wscript.Quit 1
Else
    strTarget = WScript.Arguments.Item(0)
End If

' Get file paths
strTempFolder = objFSO.GetSpecialFolder(2)
strReport = strTempFolder & "\" & objFSO.GetTempName
strFullScript = Wscript.ScriptFullName
Set objFullScript = objFSO.GetFile(strFullScript)
strFullPath = objFSO.GetParentFolderName(objFullScript)
strHtmlReport = strFullPath & "\..\Reports\" & strTarget & ".html"
'DEBUG
'Dim strXMLReport
'strXMLReport = strFullPath & "\..\Reports\" & strTarget & ".xml"
'End DEBUG
strUpdateReport = strFullPath & "\..\Reports\NeedsUpdate.txt"
strStylesheet = strFullPath & "\..\util\serverhtml.xsl"
strLogo = "LOGO.jpg"
strCl = strFullPath & "\..\sydi-server\sydi-server.vbs -t" & strTarget & " -ex -o" & strReport & " -sh"
strClH = strFullPath & "\..\sydi-server\tools\sydi-transform.vbs -x" & strReport & " -s" &strStylesheet & " -o" & strHtmlReport
objShell.Run "cscript.exe " & strCl, 0, vbTrue

Set xmlDoc = CreateObject("Microsoft.XMLDOM")
xmlDoc.Async = "False"
xmlDoc.Load(strReport)

Set xmlDocVals = CreateObject("Microsoft.XMLDOM")
xmlDocVals.Async = "False"
xmlDocVals.Load(strFullPath & "\..\util\software.xml")


Sub DoSoftwareSearch
    For Each objNodeVals in colNodesVals
        'Set to false by default
        bPrintValues = False

        'name and expected_version are required
        objRegExp.IgnoreCase = False
        objRegExp.Pattern = objNodeVals.Attributes.getNamedItem("name").Text
        bTestName = objRegExp.Test(objNode.Attributes.getNamedItem("productname").Text)

        'Redefine bTestName if it is intened to be exact match ("literal")
        If (objNodeVals.Attributes.getNamedItem("literal").Text) Then
            bTestName = (objNodeVals.Attributes.getNamedItem("name").Text = objNode.Attributes.getNamedItem("productname").Text)
        End if

        If (bTestName) Then
            ' the value of "name" was found somewhere in the value of "productname"
            ' now check for "expected_version" in "version"
            objRegExp.IgnoreCase = True
            objRegExp.Pattern = objNodeVals.Attributes.getNamedItem("expected_version").Text
            bTestVersion = objRegExp.Test(objNode.Attributes.getNamedItem("version").Text)
            If Not (bTestVersion) Then
                'Ok, we have a mismatch, so it should be printed if "include" and "exclude" hold true
                'include and exclude are conditional on null and test only against "productname"
                bPrintValues = True
                If Len(objNodeVals.Attributes.getNamedItem("include").Text & "") > 0 Then
                    ' the value of "include" is not empty, test it...
                    objRegExp.IgnoreCase = False
                    objRegExp.Pattern = objNodeVals.Attributes.getNamedItem("include").Text
                    bTestInclude = objRegExp.Test(objNode.Attributes.getNamedItem("productname").Text)
                    If Not (bTestInclude) Then
                        bPrintValues = False
                    End If
                End If
                If Len(objNodeVals.Attributes.getNamedItem("exclude").Text & "") > 0 Then
                    ' the value of "exclude" is not empty, test it...
                    objRegExp.IgnoreCase = False
                    objRegExp.Pattern = objNodeVals.Attributes.getNamedItem("exclude").Text
                    bTestExclude = objRegExp.Test(objNode.Attributes.getNamedItem("productname").Text)
                    If (bTestExclude) Then
                        bPrintValues = False
                    End If
                End If
            End If
        End If
        If (bPrintValues) Then
            strSoftwareList = strSoftwareList & "        " & objNode.Attributes.getNamedItem("productname").Text & " - " & objNode.Attributes.getNamedItem("version").Text & vbCrLf
        End If
    Next
End Sub

' Iterate through MSI applications
Set colNodes=xmlDoc.selectNodes ("//computer/installedapplications/msiapplication")
Set colNodesVals=xmlDocVals.selectNodes ("//check/software/search")

For Each objNode in colNodes
    DoSoftwareSearch
Next

'Same thing for registry applications
Set colNodesReg=xmlDoc.selectNodes("//computer/installedapplications/regapplication")
For Each objNode in colNodesReg
    ' GRR--Adobe AIR shows up in both msiapplications and regapplications for some reason
    objRegExp.IgnoreCase = False
    objRegExp.Pattern = "Adobe AIR"
    bTestName = objRegExp.Test(objNode.Attributes.getNamedItem("productname").Text)
    If Not (bTestName) Then
        DoSoftwareSearch
    End If
Next

' Determine OS verison

Set colNodeOS=xmlDoc.selectNodes("//computer/operatingsystem")
For Each objNode in ColNodeOS
    strAPIVer = objNode.Attributes.getNamedItem("osapi").Text
    strOSCaption = objNode.Attributes.getNamedItem("name").Text
    strOSBuild = objNode.Attributes.getNamedItem("build").Text
Next

' Is this Server
bOSServer = False
objRegExp.IgnoreCase = False
objRegExp.Pattern = "Server"
If (objRegExp.Test(strOSCaption)) Then
	bOSServer = True
	'Determine if Core or Full(minimal is same as full for purposes of security patches)
	'For Server core and Minimal, check server features for ID 99 and 478, if both, it's full, if only 478, it's minimal (full), if neither it's core
	set colNodesFeatures=xmlDoc.selectNodes("//computer/server_features/feature")
	bHasGUITools = False
	bHasGUI = False
	For Each objNode in colNodesFeatures
	    If objNode.Attributes.getNamedItem("id").Text = "478" Then
		    bHasGUITools = True
		End If
		If objNode.Attributes.getNamedItem("id").Text = "99" Then
		    bHasGUI = True
		End If
	Next
	'Tag Core as C
	If Not bHasGUITools Then
		'This is core
		strAPIVer = strAPIVer & "C"
	Else
		'This is just Serer
		strAPIVer = strAPIVer & "S"
	End If
End If

' Tag RT as R
bOSRT = False
objRegExp.IgnoreCase = False
objRegExp.Pattern = "RT"
If (objRegExp.Test(strOSCaption)) Then
    bOSRT = True
    strAPIVer = strAPIVer & "R"
End If

' Determine Windows 10 update build
If ((strAPIVer = "10.0") And Not (strOSBuild = "10240")) Then
    bPostOSRelease = True
    strAPIVer = "10.1511"
End If

' Tag as F if not RT, Server, or a post relase build
If (Not (bOSRT) And Not (bOSServer) And Not (bPostOSRelease)) Then
    strAPIVer = strAPIVer & "F"
End If


'Iterate through OS Patches
Set colNodesPatches=xmlDoc.selectNodes ("//computer/patches/patch")
Set colNodesOSPatch=xmlDocVals.selectNodes ("//check/updates/os_update")
For Each objNode in colNodesOSPatch
    objRegExp.IgnoreCase = False
    objRegExp.Pattern = strAPIVer
    'Default to false
    bPrintValues = False
    bTestOS = objRegExp.Test(objNode.Attributes.getNamedItem("os").Text)
	If (bTestOS) Then
	    'OS Matches (Presumably, we still haven't dealt with R and C modifiers)
		
		'RT should be in product name (caption)
        For Each objNodeVals in colNodesPatches
		    If (objNode.Attributes.getNamedItem("kbid").Text = objNodeVals.Attributes.getNamedItem("hotfixid").Text) Then
	            'we found a match
				bPrintValues = False
				Exit For
			Else
			    bPrintValues = True
			End If
	    Next
	End If
	If (bPrintValues) Then
	    strSoftwareList = strSoftwareList & "        KB" & objNode.Attributes.getNamedItem("kbid").Text & ": " & objNode.Attributes.getNamedItem("desc").Text & vbCrLf
	End If
Next

' Determine Office version
strOfficeVersion = "Nothing"
For Each objNode in colNodesReg
	objRegExp.IgnoreCase = False
	objRegExp.Pattern = "Office"
	If (objRegExp.Test(objNode.Attributes.getNamedItem("productname").Text)) Then
		colOVers=Array("10","11","12","14","15","16")
		For Each objNodeOVers in colOVers
		    objRegExp.IgnoreCase = False
			objRegExp.Pattern = objNodeOVers & "."
			If (objRegExp.Test(objNode.Attributes.getNamedItem("version").Text)) Then
				strOfficeVersion = objNodeOVers
			End If
		Next
	End If
Next
'DEBUG
'wscript.Echo "Office Version: " & strOfficeVersion
'End DEBUG

'Iterate through Office Patches
set colNodesOfficePatch=xmlDocVals.selectNodes ("//check/updates/office_update")
For Each objNode in colNodesOfficePatch
    bPrintValues = False
    objRegExp.IgnoreCase = False
	objRegExp.Pattern = strOfficeVersion
    If (objRegExp.Test(objNode.Attributes.getNamedItem("ov").Text)) Then
	    'We have applicable version
		'iterate through installed patches against
		For Each objNodeVals in colNodesPatches
		    If (objNode.Attributes.getNamedItem("kbid").Text = objNodeVals.Attributes.getNamedItem("hotfixid").Text) Then
	            'we found a match
				bPrintValues = False
				Exit For
			Else
			    bPrintValues = True
			End If
	    Next
	End If
	If (bPrintValues) Then
	    strSoftwareList = strSoftwareList & "        KB" & objNode.Attributes.getNamedItem("kbid").Text & ": " & objNode.Attributes.getNamedItem("desc").Text & vbCrLf
	End If
'DEBUG
'wscript.echo "Office: " & objNode.Attributes.getNamedItem("kbid").Text
'End DEBUG
Next

' We might not have a NeedsUpdate.txt yet (if running singly)
If Not objFSO.FileExists(strUpdateReport) Then
    Set objFile = objFSO.CreateTextFile(strUpdateReport)
	objFile.Close
    Set objTextFile = objFSO.OpenTextFile(strUpdateReport, 8, True)
    objTextFile.WriteLine("The following PCs need the listed software updated to the latest version and security patches applied:" & vbCrLf)
Else
    IsOpen(strUpdateReport)
    Set objTextFile = objFSO.OpenTextFile(strUpdateReport, 8, True)
End If

' Append to file, but don't write anything if strSoftwareList is empty
If Len(strSoftwareList & "") > 0 Then
    objTextFile.WriteLine(strTarget & ":")
    objTextFile.WriteLine(strSoftwareList)
End If
objTextFile.Close

' Write the HTML Report
If objFSO.FileExists(strReport) Then
    objShell.Run "cscript.exe " & strClH, 0, vbTrue
'DEBUG
'objFSO.CopyFile strReport, strXMLReport
'End DEBUG
    objFSO.DeleteFile(strReport)
End If

If Not objFSO.FileExists(strFullPath & "\..\Reports\" & strLogo) Then
    objFSO.CopyFile strFullPath & "\..\util\" & strLogo, strFullPath & "\..\Reports\"
End If

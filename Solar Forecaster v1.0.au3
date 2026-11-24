#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=resources\phoenix_5Vq_icon.ico
#AutoIt3Wrapper_Outfile=Builds\Solar Forecaster.exe
#AutoIt3Wrapper_Run_AU3Check=n
#AutoIt3Wrapper_Tidy_Stop_OnError=n
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#include <Date.au3>
#include <MsgBoxConstants.au3>
#include <Array.au3>
#include <WinAPIIcons.au3>
#include <WinAPISysWin.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <String.au3>
#include <File.au3>
#include <FTPEx.au3>
#include <INet.au3>
#include <TrayConstants.au3>

; Created with the assistance of Copilot AI

Global $aUtilName = "Solar Forecaster"
Global $aUtilVersion = "v1.0"
Global $aUtilityVer = $aUtilName & " " & $aUtilVersion
Global $aUtilVerNumber = 1
; 1 = v1.0 2026-11-23

Global $aConfigFolder = @ScriptDir & "\_Config"
Global $aLogFolder = @ScriptDir & "\_Log"
Global $aLogFile = $aLogFolder & "\Log_" & @YEAR & "-" & @MON & "-" & @MDAY & ".txt"
Global $sReport = ""
Global $sJson = 0

Global $aMDAY = @MDAY
Global $aCmdLnFile = "Config.ini"
If $CmdLine[0] > 0 Then
	Local $tTxt = ""
	For $t = 1 To $CmdLine[0]
		$tTxt &= $CmdLine[$t] & " "
		If $CmdLine[$t] = "-h" Then
			Help()
		ElseIf $CmdLine[$t] = "-f" Then
		Else
			If FileExists(@ScriptDir & "\" & $CmdLine[$t]) Then
				$aCmdLnFile = @ScriptDir & "\" & $CmdLine[$t]
			Else
				$aCmdLnFile = $CmdLine[$t]
			EndIf
		EndIf
	Next
	LogWrite("[ SYS  ] Commandline parameter(s) found[" & StringTrimRight($tTxt, 1) & "]")
EndIf
Global $aIniFile = $aConfigFolder & "\" & $aCmdLnFile
If Not FileExists($aConfigFolder) Then
	Do
		DirCreate($aConfigFolder)
	Until FileExists($aConfigFolder)
EndIf
If Not FileExists($aLogFolder) Then
	Do
		DirCreate($aLogFolder)
	Until FileExists($aLogFolder)
EndIf
Local $tLabel = "                      " & $aUtilityVer & " Started                      "
Local $tBorder = ""
For $t = 1 To StringLen($tLabel)
	$tBorder &= "_"
Next
LogWrite($tBorder)
LogWrite(".")
LogWrite($tLabel)
LogWrite($tBorder)

UiniRead()
_ConvertYN()
If $aEnableAltEscYN = "Yes" Then HotKeySet("!{Esc}", "_EscapeKeyPressed")
_StartTray()
If $aFreeVersionYN <> "yes" And $APIKEY = "0123456789abcdef" Then
	Local $tTxt = "Configuration Error: API Key not found in config.ini"
	LogWrite("[ERROR ] " & $tTxt)
	_MsgBox(0, $aUtilName, $tTxt)
	_Exit()
EndIf
If $aFreeVersionYN <> "yes" Then
	Global $URL = "https://api.forecast.solar/" & $APIKEY & "/estimate/" & $LATITUDE & "/" & $LONGITUDE & "/" & $TILT & "/" & $AZIMUTH & "/" & $KWP
	If $APIKEY = "0123456789abcdef" Then
		Local $tTxt = "Configuration Error: API Key not found in config.ini"
		LogWrite("[ERROR ] " & $tTxt)
		_MsgBox(0, $aUtilName, $tTxt)
		_Exit()
	EndIf
Else
	Global $URL = "https://api.forecast.solar/estimate/" & $LATITUDE & "/" & $LONGITUDE & "/" & $TILT & "/" & $AZIMUTH & "/" & $KWP
EndIf
Global Const $CACHEFILE = $aConfigFolder & "\forecast_cache.json"
If $CmdLine[0] > 0 And StringLower($CmdLine[1]) = "/refresh" Then FileDelete($CACHEFILE)

Global $aPreText = ""
Global $aSplash = 0

$sReport = _UpdateData()
Local $sMB = _MsgBox("Always On Top;Floating;Exit", $aUtilName, $sReport, "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", $aAddToWidth, 0)
If $sMB = "Always On Top" Then
	Global $sParams = $DLG_MOVEABLE + $DLG_TEXTLEFT
	_ContinuousDisplay()
ElseIf $sMB = "Floating" Then
	Global $sParams = $DLG_MOVEABLE + $DLG_TEXTLEFT + $DLG_NOTONTOP
	_ContinuousDisplay()
ElseIf $sMB = "Exit" Then
	_ExitUtil()
EndIf

_ExitUtil()

Func _UpdateData()
	Local $tJson = GetForecastData($URL)
	If $tJson = "" Then
		_MsgBox(0, "Error", "Unable to retrieve forecast data.")
		_Exit()
	EndIf
	Local $tReport = $aPreText
	Local $tBuildReportSolar = BuildReportSolar($tJson)
	Local $tBuildReportEV = BuildReportEV($tJson)
	Local $tBuildReportBarChart = BuildTextBarChart($tBuildReportSolar)
	LogWrite("[LOCATN] Location: " & $LATITUDE & "," & $LONGITUDE)
	LogWrite("[FORCST] " & $tBuildReportSolar)
	LogWrite("[FORCST] " & $tBuildReportEV)
	LogWrite("[FORCST] FORCAST GRAPH|" & $tBuildReportBarChart)
	If $INCLUDEFULLSOLAR Then $tReport &= $tBuildReportSolar
	If $INCLUDEEV Then $tReport &= $tBuildReportEV
	If $INCLUDEFULLSOLAR Or $INCLUDEEV Then $tReport &= @CRLF & @CRLF
	If $INCLUDEGRAPH Then $tReport &= $tBuildReportBarChart
	LogWrite("[OUTPUT] " & $tReport)
	Return $tReport
EndFunc   ;==>_UpdateData

Func _ContinuousDisplay()
	$tStop = False
	If $aEnableAltEscYN = "Yes" Then
		$tEnableAltEsc = "     |     Press {ALT}+{ESC} to Exit"
	Else
		$tEnableAltEsc = ""
	EndIf
	Local $tTimeCountMinutes = $aRefreshInMinutes - 1
	Local $tTimeCountSeconds = 59
	Local $tLines = StringSplit(StringStripCR($sReport), @LF, 1)[0]
	Local $tHeight = 20 * ($tLines + 4)
	$aSplash = _Splash("", 0, 500, $tHeight, $sParams)
		Do
		Local $tTxt = $sReport & @CRLF & @CRLF & "Refresh in " & $tTimeCountMinutes & ":" & StringFormat("%02i", $tTimeCountSeconds) & $tEnableAltEsc
		ControlSetText($aSplash, "", "Static1", $tTxt)
		$tTimeCountSeconds -= 1
		If $tTimeCountSeconds = -1 Then
			$tTimeCountSeconds = 59
			$tTimeCountMinutes -= 1
		EndIf
		If $tTimeCountMinutes = -1 Then
			$tTimeCountMinutes = $aRefreshInMinutes - 1
			$sReport = _UpdateData()
		EndIf
		Sleep(1000)
	Until $tStop
EndFunc   ;==>_ContinuousDisplay

Func HttpGet($sURL)
	Local $oHTTP = ObjCreate("WinHttp.WinHttpRequest.5.1")
	$oHTTP.Open("GET", $sURL, False)
	$oHTTP.Send()
	If $oHTTP.Status = 429 Then
		_MsgBox(0, "Rate Limit Reached", "Forecast.Solar has temporarily blocked requests." & @CRLF & @CRLF & "Please wait and try again later.")
		Return ""
	EndIf
	If $oHTTP.Status <> 200 Then
		_MsgBox(0, "HTTP Error", "Status Code: " & $oHTTP.Status)
		Return ""
	EndIf
	FileDelete($CACHEFILE)
	FileWrite($CACHEFILE, $sJson)
	Return $oHTTP.ResponseText
EndFunc   ;==>HttpGet

Func BuildReportSolar($sJson)
	Local $sOutput = ""
	; DAILY TOTALS
	Local $aMatch = StringRegExp($sJson, '"watt_hours_day"\s*:\s*\{([^}]*)\}', 1)
	If Not @error Then
		Local $aDays = StringRegExp($aMatch[0], '"([^"]+)"\s*:\s*(\d+)', 3)
		If Not @error Then
			Local $fTotal = 0
			$sOutput &= "SOLAR FORECAST" & @CRLF
			$sOutput &= "==============" & @CRLF
			For $i = 0 To UBound($aDays) - 1 Step 2
				Local $sDate = $aDays[$i]
				Local $fKWh = Round(Number($aDays[$i + 1]) / 1000, 2)
				$fTotal += $fKWh
				$sOutput &= $sDate & " : " & $fKWh & " kWh" & @CRLF
			Next
			$sOutput &= @CRLF
			$sOutput &= "Forecast Total: " & Round($fTotal, 2) & " kWh" & @CRLF & @CRLF
		EndIf
	EndIf
	Return $sOutput
EndFunc   ;==>BuildReportSolar

Func BuildReportEV($sJson)
	; HOURLY WATTS
	Local $sOutput = ""
	Local $aHours = StringRegExp($sJson, '"(\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2})"\s*:\s*(\d+)', 3)
	If @error Then Return $sOutput & "Unable to analyze hourly forecast."
	Local $iCount = UBound($aHours) / 2
	Local $fPeakWatts = 0
	Local $sPeakTime = ""
	For $i = 0 To (($iCount - 1) * 2) Step 2
		Local $sTime = $aHours[$i]
		Local $fWatts = Number($aHours[$i + 1])
		If $fWatts > $fPeakWatts Then
			$fPeakWatts = $fWatts
			$sPeakTime = StringMid($sTime, 12, 5)
		EndIf
	Next
	; BEST 4-HOUR WINDOW
	Local $fBestWh = 0
	Local $sStart = ""
	Local $sEnd = ""
	For $i = 0 To (($iCount - 4) * 2) Step 2
		Local $fWindowWh = 0
		For $j = 0 To 3
			$fWindowWh += Number($aHours[$i + ($j * 2) + 1])
		Next
		If $fWindowWh > $fBestWh Then
			$fBestWh = $fWindowWh
			$sStart = StringMid($aHours[$i], 12, 5)
			$sEnd = StringMid($aHours[$i + 6], 12, 5)
		EndIf
	Next
	Local $fPeakKW = Round($fPeakWatts / 1000, 2)
	Local $fChargeKWh = Round($fBestWh / 1000, 2)
	Local $iAmps = GetRecommendedAmps($fPeakKW)
	Local $fRangeAdded = Round($fChargeKWh * $MILES_PER_KWH)
	$sOutput &= "EV CHARGING" & @CRLF
	$sOutput &= "===========" & @CRLF
	$sOutput &= "Peak Solar Time : " & $sPeakTime & @CRLF
	$sOutput &= "Peak Output     : " & $fPeakKW & " kW" & @CRLF & @CRLF
	$sOutput &= "Best Charge Window" & @CRLF
	$sOutput &= $sStart & " - " & $sEnd & @CRLF & @CRLF
	$sOutput &= "Solar Available : " & $fChargeKWh & " kWh" & @CRLF
	$sOutput &= "Recommended Rate: " & $iAmps & "A" & @CRLF
	$sOutput &= "Mach-E Range    : +" & $fRangeAdded & " miles"
	Return $sOutput
EndFunc   ;==>BuildReportEV

Func GetRecommendedAmps($fPeakKW)
	If $fPeakKW >= 11 Then Return 48
	If $fPeakKW >= 9 Then Return 40
	If $fPeakKW >= 7 Then Return 32
	If $fPeakKW >= 5 Then Return 24
	Return 16
EndFunc   ;==>GetRecommendedAmps

Func GetForecastData($sURL)
	If FileExists($CACHEFILE) Then
		Local $iAgeMinutes = CacheAgeMinutes($CACHEFILE)
		If $iAgeMinutes >= 0 And $iAgeMinutes < $CACHE_AGE_MINUTES Then
			$aPreText = "Using cached forecast data (" & $iAgeMinutes & " minutes old)" & @CRLF & @CRLF
			ConsoleWrite($aPreText)
			Return FileRead($CACHEFILE)
		EndIf
	EndIf
	$sJson = HttpGet($sURL)
	If $sJson <> "" Then
		FileDelete($CACHEFILE)
		FileWrite($CACHEFILE, $sJson)
	EndIf
	Return $sJson
EndFunc   ;==>GetForecastData

Func CacheAgeMinutes($sFile)
	Local $aModified = FileGetTime($sFile, 0)
	If @error Then Return -1
	Local $sModified = $aModified[0] & "/" & $aModified[1] & "/" & $aModified[2] & " " & $aModified[3] & ":" & $aModified[4] & ":" & $aModified[5]
	Local $iModified = _DateDiff('s', $sModified, _NowCalc())
	Return Int($iModified / 60)
EndFunc   ;==>CacheAgeMinutes

Func BuildTextBarChart($sReport)
	Local $aLines = StringSplit($sReport, @CRLF, 1)
	Local $fMax = 0
	Local $aDays[0]
	Local $aValues[0]
	For $i = 1 To $aLines[0]
		If StringRegExp($aLines[$i], "\d{4}-\d{2}-\d{2}") Then
			Local $aMatch = StringRegExp($aLines[$i], '(\d{4}-\d{2}-\d{2})\s*:\s*([\d\.]+)', 1)
			If Not @error Then
				Local $iIndex = UBound($aDays)
				ReDim $aDays[$iIndex + 1]
				ReDim $aValues[$iIndex + 1]
				$aDays[$iIndex] = DateToDayName($aMatch[0])
				$aValues[$iIndex] = Number($aMatch[1])
				If $aValues[$iIndex] > $fMax Then $fMax = $aValues[$iIndex]
			EndIf
		EndIf
	Next
	Local $sChart = ""
	If $INCLUDEGRAPHHEADER Then $sChart &= "SOLAR OUTPUT CHART" & @CRLF & "==================" & @CRLF
	For $i = 0 To UBound($aDays) - 1
		Local $iBars = Round(($aValues[$i] / $fMax) * 20)
		Local $sBar = ""
		For $j = 1 To $iBars
			$sBar &= "█"
		Next
		$sChart &= $aDays[$i] & " " & $sBar & "   " & Round($aValues[$i], 1) & " kWh" & @CRLF
	Next
	Return $sChart
EndFunc   ;==>BuildTextBarChart

Func DateToDayName($sDate)
	Local $aDateSplit = StringSplit($sDate, "-", 2)
	Local $iDow = _DateToDayOfWeekISO($aDateSplit[0], $aDateSplit[1], $aDateSplit[2])
	Switch $iDow
		Case 1
			Return "Mon" & @TAB
		Case 2
			Return "Tues" & @TAB
		Case 3
			Return "Wed" & @TAB
		Case 4
			Return "Thurs" & @TAB
		Case 5
			Return "Fri" & @TAB
		Case 6
			Return "Sat" & @TAB
		Case 7
			Return "Sun" & @TAB
	EndSwitch
	Return $sDate
EndFunc   ;==>DateToDayName

Func UiniSetLabels()
	Global $shForecastSolar = " --------------- FORECAST.SOLAR CONFIGURATION --------------- "
	Global $slFreeVersionYN = "Use Forecast.Solar Free account? (Yes/No) ###"
	Global $slAPIKEY = "ApiKey (Enter key of using paid account)  ###"
	Global $shSolarSite = " --------------- SOLAR SITE CONFIGURATION --------------- "
	Global $slLATITUDE = "Latitude  (decimal 0.0000) ###"
	Global $slLONGITUDE = "Longitude (decimal 0.0000) ###"
	Global $slTILT = "Tilt             (degrees) ###"
	Global $slAZIMUTH = "Azimuth                    ###"
	Global $slKWP = "KWP   (kW of solar panels) ###"
	Global $shEV = " --------------- EV CONFIGURATION --------------- "
	Global $slMILES_PER_KWH = "Miles Per KWh              ###"
	Global $shProg = " --------------- PROGRAM CONFIGURATION --------------- "
	Global $slRefreshInMinutes = "Refresh data every _ minutes                     (5-999) ###"
	Global $slCACHE_AGE_MINUTES = "Cache Age                                      (Minutes) ###"
	Global $slDeleteLog = "Delete log files older than _ days   (0-Disable) (0-999) ###"
	Global $slAddToWidth = "Added pixel width to results window              (0-999) ###"
	Global $slEnableAltEscYN = "Enable Alt-Esc to close program                 (Yes/No) ###"
	Global $shOutput = " --------------- OUTPUT CONFIGURATION --------------- "
	Global $slINCLUDEEV = "Include EV Data?                                (Yes/No) ###"
	Global $slINCLUDEFULLSOLAR = "Include Full Solar Data?                        (Yes/No) ###"
	Global $slINCLUDEGRAPH = "Include Solar Graph?                            (Yes/No) ###"
	Global $slINCLUDEGRAPHHEADER = "Include Solar Graph Header?                     (Yes/No) ###"
EndFunc   ;==>UiniSetLabels

Func UiniRead()
	LogWrite("[CONFIG] Importing settings from " & $aUtilName & ".ini")
	UiniSetLabels()
	Local $iIniError = ""
	Local $iIniFail = 0
	Local $iniCheck = ""
	Local $aChar[3]
	For $i = 1 To 13
		$aChar[0] = Chr(Random(97, 122, 1)) ;a-z
		$aChar[1] = Chr(Random(48, 57, 1)) ;0-9
		$iniCheck &= $aChar[Random(0, 1, 1)]
	Next
	Global $aFreeVersionYN = IniRead($aIniFile, $shForecastSolar, $slFreeVersionYN, $iniCheck)
	Global $APIKEY = IniRead($aIniFile, $shForecastSolar, $slAPIKEY, $iniCheck)

	Global $LATITUDE = IniRead($aIniFile, $shSolarSite, $slLATITUDE, $iniCheck)
	Global $LONGITUDE = IniRead($aIniFile, $shSolarSite, $slLONGITUDE, $iniCheck)
	Global $TILT = IniRead($aIniFile, $shSolarSite, $slTILT, $iniCheck)
	Global $AZIMUTH = IniRead($aIniFile, $shSolarSite, $slAZIMUTH, $iniCheck)
	Global $KWP = IniRead($aIniFile, $shSolarSite, $slKWP, $iniCheck)

	Global $MILES_PER_KWH = Number(IniRead($aIniFile, $shEV, $slMILES_PER_KWH, $iniCheck))

	Global $aRefreshInMinutes = Number(IniRead($aIniFile, $shProg, $slRefreshInMinutes, $iniCheck))
	Global $CACHE_AGE_MINUTES = Number(IniRead($aIniFile, $shProg, $slCACHE_AGE_MINUTES, $iniCheck))
	Global $aDeleteLog = IniRead($aIniFile, $shProg, $slDeleteLog, $iniCheck)
	Global $aAddToWidth = IniRead($aIniFile, $shProg, $slAddToWidth, $iniCheck)
	Global $aEnableAltEscYN = IniRead($aIniFile, $shProg, $slEnableAltEscYN, $iniCheck)

	Global $INCLUDEEV = IniRead($aIniFile, $shOutput, $slINCLUDEEV, $iniCheck)
	Global $INCLUDEFULLSOLAR = IniRead($aIniFile, $shOutput, $slINCLUDEFULLSOLAR, $iniCheck)
	Global $INCLUDEGRAPH = IniRead($aIniFile, $shOutput, $slINCLUDEGRAPH, $iniCheck)
	Global $INCLUDEGRAPHHEADER = IniRead($aIniFile, $shOutput, $slINCLUDEGRAPHHEADER, $iniCheck)
	If $iniCheck = $aFreeVersionYN Then
		$aFreeVersionYN = "Yes"
		$iIniFail += 1
		$iIniError = $iIniError & "$aFreeVersionYN, "
	EndIf
	If $iniCheck = $APIKEY Then
		$APIKEY = "0123456789abcdef"
		$iIniFail += 1
		$iIniError = $iIniError & "$APIKEY, "
	EndIf
	If $iniCheck = $LATITUDE Then
		$LATITUDE = "32.7831"
		$iIniFail += 1
		$iIniError = $iIniError & "$LATITUDE, "
	EndIf
	If $iniCheck = $LONGITUDE Then
		$LONGITUDE = "-96.8067"
		$iIniFail += 1
		$iIniError = $iIniError & "$LONGITUDE, "
	EndIf
	If $iniCheck = $TILT Then
		$TILT = "40"
		$iIniFail += 1
		$iIniError = $iIniError & "$TILT, "
	EndIf
	If $iniCheck = $AZIMUTH Then
		$AZIMUTH = "0"
		$iIniFail += 1
		$iIniError = $iIniError & "$AZIMUTH, "
	EndIf
	If $iniCheck = $KWP Then
		$KWP = "10"
		$iIniFail += 1
		$iIniError = $iIniError & "$KWP, "
	EndIf
	If $iniCheck = $MILES_PER_KWH Then
		$MILES_PER_KWH = "3.5"
		$iIniFail += 1
		$iIniError = $iIniError & "$MILES_PER_KWH, "
	EndIf
	If $iniCheck = $aRefreshInMinutes Then
		$aRefreshInMinutes = "60"
		$iIniFail += 1
		$iIniError = $iIniError & "$aRefreshInMinutes, "
	EndIf
	If $iniCheck = $CACHE_AGE_MINUTES Then
		$CACHE_AGE_MINUTES = "60"
		$iIniFail += 1
		$iIniError = $iIniError & "$CACHE_AGE_MINUTES, "
	EndIf
	If $iniCheck = $aDeleteLog Then
		$aDeleteLog = "900"
		$iIniFail += 1
		$iIniError = $iIniError & "$aDeleteLog, "
	EndIf
	If $iniCheck = $aAddToWidth Then
		$aAddToWidth = "300"
		$iIniFail += 1
		$iIniError = $iIniError & "$aAddToWidth, "
	EndIf
	If $iniCheck = $aEnableAltEscYN Then
		$aEnableAltEscYN = "No"
		$iIniFail += 1
		$iIniError = $iIniError & "$aEnableAltEscYN, "
	EndIf
	If $iniCheck = $INCLUDEEV Then
		$INCLUDEEV = "Yes"
		$iIniFail += 1
		$iIniError = $iIniError & "$INCLUDEEV, "
	EndIf
	If $iniCheck = $INCLUDEFULLSOLAR Then
		$INCLUDEFULLSOLAR = "Yes"
		$iIniFail += 1
		$iIniError = $iIniError & "$INCLUDEFULLSOLAR, "
	EndIf
	If $iniCheck = $INCLUDEGRAPH Then
		$INCLUDEGRAPH = "Yes"
		$iIniFail += 1
		$iIniError = $iIniError & "$INCLUDEGRAPH, "
	EndIf
	If $iniCheck = $INCLUDEGRAPHHEADER Then
		$INCLUDEGRAPHHEADER = "Yes"
		$iIniFail += 1
		$iIniError = $iIniError & "$INCLUDEGRAPHHEADER, "
	EndIf
	If $aRefreshInMinutes < 5 Then $aRefreshInMinutes = 5
	If $aRefreshInMinutes > 999 Then $aRefreshInMinutes = 999
	If $aRefreshInMinutes - $CACHE_AGE_MINUTES < 2 Then $CACHE_AGE_MINUTES -= 2
	If $aDeleteLog < 0 Then $aDeleteLog = 0
	If $aDeleteLog > 999 Then $aDeleteLog = 999
	If $aAddToWidth < 0 Then $aAddToWidth = 0
	If $aAddToWidth > 999 Then $aAddToWidth = 999
	;   - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	If Not FileExists($aIniFile) Then
		LogWrite("[CONFIG] Config file [" & $aIniFile & "] not found.")
		UninWrite()
		ShellExecute($aIniFile)
		Sleep(1500)
		Local $aMsg = "Thank you for installing " & $aUtilName & "." & @CRLF & @CRLF & _
				"\_Config\Config.ini file was created and opened. Make any desired changes to the config file then restart the program." & @CRLF & @CRLF & _
				"Click (README) to open the readme.txt file for more information." & @CRLF & _
				"Click (EXIT) to exit utility."
		$tMB = _MsgBox("README;EXIT", $aUtilName, $aMsg, 30)
		If $tMB = "README" Then ShellExecute(@ScriptDir & "\readme.txt")
		If $tMB = "EXIT" Then _Exit()
		_Exit()
	EndIf
	If $iIniFail > 0 Then
		LogWrite("[CONFIG] Error or new parameter in config file. All detected settings have been saved and undetected settings set to default [" & StringTrimRight($iIniError, 1) & "]")
		UninWrite()
	EndIf
EndFunc   ;==>UiniRead
Func _ConvertYN()
	If $INCLUDEEV = "Yes" Then
		$INCLUDEEV = True
	Else
		$INCLUDEEV = False
	EndIf
	If $INCLUDEFULLSOLAR = "Yes" Then
		$INCLUDEFULLSOLAR = True
	Else
		$INCLUDEFULLSOLAR = False
	EndIf
	If $INCLUDEGRAPH = "Yes" Then
		$INCLUDEGRAPH = True
	Else
		$INCLUDEGRAPH = False
	EndIf
	If $INCLUDEGRAPHHEADER = "Yes" Then
		$INCLUDEGRAPHHEADER = True
	Else
		$INCLUDEGRAPHHEADER = False
	EndIf
EndFunc   ;==>_ConvertYN
Func UninWrite()
	FileDelete($aIniFile)
	FileWriteLine($aIniFile, "[ --------------- " & StringUpper($aUtilName) & " INFORMATION --------------- ]")
	FileWriteLine($aIniFile, "Author   :  Phoenix125")
	FileWriteLine($aIniFile, "Version  :  " & $aUtilVersion)
	FileWriteLine($aIniFile, "Website  :  http://www.Phoenix125.com")
	FileWriteLine($aIniFile, "Discord  :  http://discord.gg/EU7pzPs")
	FileWriteLine($aIniFile, @CRLF)
	IniWrite($aIniFile, $shForecastSolar, $slFreeVersionYN, $aFreeVersionYN)
	IniWrite($aIniFile, $shForecastSolar, $slAPIKEY, $APIKEY)
	FileWriteLine($aIniFile, @CRLF)
	IniWrite($aIniFile, $shSolarSite, $slLATITUDE, $LATITUDE)
	IniWrite($aIniFile, $shSolarSite, $slLONGITUDE, $LONGITUDE)
	IniWrite($aIniFile, $shSolarSite, $slTILT, $TILT)
	IniWrite($aIniFile, $shSolarSite, $slAZIMUTH, $AZIMUTH)
	IniWrite($aIniFile, $shSolarSite, $slKWP, $KWP)
	FileWriteLine($aIniFile, @CRLF)
	IniWrite($aIniFile, $shEV, $slMILES_PER_KWH, $MILES_PER_KWH)
	FileWriteLine($aIniFile, @CRLF)
	IniWrite($aIniFile, $shProg, $slRefreshInMinutes, $aRefreshInMinutes)
	IniWrite($aIniFile, $shProg, $slCACHE_AGE_MINUTES, $CACHE_AGE_MINUTES)
	IniWrite($aIniFile, $shProg, $slDeleteLog, $aDeleteLog)
	IniWrite($aIniFile, $shProg, $slAddToWidth, $aAddToWidth)
	IniWrite($aIniFile, $shProg, $slEnableAltEscYN, $aEnableAltEscYN)
	FileWriteLine($aIniFile, @CRLF)
	IniWrite($aIniFile, $shOutput, $slINCLUDEEV, $INCLUDEEV)
	IniWrite($aIniFile, $shOutput, $slINCLUDEFULLSOLAR, $INCLUDEFULLSOLAR)
	IniWrite($aIniFile, $shOutput, $slINCLUDEGRAPH, $INCLUDEGRAPH)
	IniWrite($aIniFile, $shOutput, $slINCLUDEGRAPHHEADER, $INCLUDEGRAPHHEADER)
EndFunc   ;==>UninWrite

Func LogWrite($Msg = "")
	$aLogFile = $aLogFolder & "\Log_" & @YEAR & "-" & @MON & "-" & @MDAY & ".txt"
	If $Msg <> "" Then
		FileWriteLine($aLogFile, _NowCalc() & " " & StringReplace($Msg, @CRLF, "|"))
	EndIf
	If @MDAY = 1 And $aMDAY > 0 Then $aMDAY = 0
	If $aMDAY = @MDAY + 1 Then
		$aMDAY = @MDAY
		PurgeLogFile()
	EndIf
EndFunc   ;==>LogWrite
Func PurgeLogFile()
	Local $aPurgeLogFileName = $aLogFolder & "PurgeLogFile.bat"
	Local $sFileExists = FileExists($aPurgeLogFileName)
	If $sFileExists = 1 Then FileDelete($aPurgeLogFileName)
	FileWriteLine($aPurgeLogFileName, "for /f ""tokens=* skip=" & $aDeleteLog & """ %%F in " & Chr(40) & "'dir """ & $aLogFolder & "Log_*.txt"" /o-d /tc /b'" & Chr(41) & " do del """ & $aLogFolder & "%%F""")
	LogWrite("[ LOG  ] Deleting log files >" & $aDeleteLog & " in folder " & $aLogFolder)
	Run($aPurgeLogFileName, "", @SW_HIDE)
EndFunc   ;==>PurgeLogFile
Func _ExitUtil()
	SplashOff()
	LogWrite("[ SYS  ] Program Ended")
	_MsgBox(0, $aUtilityVer, "Thank you for using " & $aUtilName & "." & @CRLF & @CRLF & _
			"Please report any problems or comments to: " & @CRLF & "Discord: http://discord.gg/EU7pzPs or " & @CRLF & _
			"Forum: http://phoenix125.createaforum.com/index.php. " & @CRLF & @CRLF & "Visit http://www.Phoenix125.com", 20)
	Exit
EndFunc   ;==>_ExitUtil
Func _EscapeKeyPressed()
	_Exit()
EndFunc   ;==>_EscapeKeyPressed
Func _Exit($tTxt = "")
	SplashOff()
	If $tTxt <> "" Then
		LogWrite($tTxt)
	Else
		LogWrite("[ SYS  ] Utility exited")
	EndIf
	Exit
EndFunc   ;==>_Exit
Func _Splash($tTxt, $tTime = 0, $tWidth = 400, $tHeight = 125, $tParams = $DLG_MOVEABLE + $DLG_TEXTLEFT + $DLG_NOTONTOP)
	Local $tPID = SplashTextOn($aUtilName, $tTxt, $tWidth, $tHeight, -1, -1, $tParams, "")
	If $tTime > 0 Then
		Sleep($tTime)
		SplashOff()
	EndIf
	Return $tPID
EndFunc   ;==>_Splash
Func _MsgBox($sButtons, $sTitle, $sText, $aParameter = "", $sDefaultButton = "", $sTimeout = "", $iButtonWidth = "", $iButtonHeight = "", $iButtonSeperator = "", $iLeftRightSpace = "", $iButtonBottomSpace = "", $sButtonStyle = "", _
		$iLabelTopBottomSpace = "", $sLabelStyle = "", $s_MsgBoxBkClr = "", $sButtonBkClr = "", $sButtonTxClr = "", $sLabelBkClr = "", $sLabelTxClr = "", $iTransparency = "", $sIcon = "", $iResizeMethod = "", $sOffsetX = "", $sOffsetY = "", $sAddToWidth = 0, $sAddToHeight = 0)

	; $sButtons
	; $sTitle
	; $sText
	; $aParameter = ""
	; $sDefaultButton = ""
	; $sTimeout = ""
	; $iButtonWidth = ""
	; $iButtonHeight = ""
	; $iButtonSeperator = ""
	; $iLeftRightSpace = ""
	; $iButtonBottomSpace = ""
	; $sButtonStyle = ""
	; $iLabelTopBottomSpace = ""
	; $sLabelStyle = ""
	; $s_MsgBoxBkClr = ""
	; $sButtonBkClr = ""
	; $sButtonTxClr = ""
	; $sLabelBkClr = ""
	; $sLabelTxClr = ""
	; $iTransparency = ""
	; $sIcon = ""
	; $iResizeMethod = ""
	; $sOffsetX = ""
	; $sOffsetY = ""
	; $sAddToWidth = 0
	; $sAddToHeight = 0

	Local $tsButtons = $sButtons
	Local $sDefaultBtnNo = 1
	Global $tMsgBoxEnter = 0
	If IsInt($sText) Then $sText = "" & $sText & ""
	If Number($aParameter, 0) > 0 Then
		$aParameter = "TO=" & Number($aParameter, 0)
	ElseIf StringInStr($aParameter, "=") Then
	Else
		$aParameter = Default
	EndIf
	If $aParameter <> Default Then
		Local $aSearch = [[20, 20], ["DB", "DefaultButton"], ["TO", "Timeout"], ["BW", "ButtonWidth"], ["BH", "ButtonHeight"], ["BS", "ButtonSeperator"], ["LRS", "LeftRightSpace"], ["BBS", "ButtonBottomSpace"], ["BST", "ButtonStyle"], ["LTBS", "LabelTopBottomSpace"], _
				["LST", "LabelStyle"], ["MBC", "_MsgBoxBkColor"], ["BBC", "ButtonBkColor"], ["BTC", "ButtonTxColor"], ["LBC", "LabelBkColor"], ["LTC", "LabelTxColor"], ["TR", "Transparency"], ["ICON", "Icon"], ["RM", "ResizeMethod"], ["+X", "OffsetX"], ["+Y", "OffsetY]"]]
		$aParameter = StringSplit($aParameter, ";")
		For $i = 1 To $aParameter[0]
			$x = StringSplit($aParameter[$i], "=")
			$y = _ArraySearch($aSearch, $x[1], 0, 0, 0, 2)
			If $y = -1 Then ExitLoop
			If $y = 1 And $sDefaultButton = "" Then $sDefaultButton = $x[2]
			If $y = 2 And $sTimeout = "" Then $sTimeout = $x[2]
			If $y = 3 And $iButtonWidth = "" Then $iButtonWidth = $x[2]
			If $y = 4 And $iButtonHeight = "" Then $iButtonHeight = $x[2]
			If $y = 5 And $iButtonSeperator = "" Then $iButtonSeperator = $x[2]
			If $y = 6 And $iLeftRightSpace = "" Then $iLeftRightSpace = $x[2]
			If $y = 7 And $iButtonBottomSpace = "" Then $iButtonBottomSpace = $x[2]
			If $y = 8 And $sButtonStyle = "" Then $sButtonStyle = $x[2]
			If $y = 9 And $iLabelTopBottomSpace = "" Then $iLabelTopBottomSpace = $x[2]
			If $y = 10 And $sLabelStyle = "" Then $sLabelStyle = $x[2]
			If $y = 11 And $s_MsgBoxBkClr = "" Then $s_MsgBoxBkClr = $x[2]
			If $y = 12 And $sButtonBkClr = "" Then $sButtonBkClr = $x[2]
			If $y = 13 And $sButtonTxClr = "" Then $sButtonTxClr = $x[2]
			If $y = 14 And $sLabelBkClr = "" Then $sLabelBkClr = $x[2]
			If $y = 15 And $sLabelTxClr = "" Then $sLabelTxClr = $x[2]
			If $y = 16 And $iTransparency = "" Then $iTransparency = $x[2]
			If $y = 17 And $sIcon = "" Then $sIcon = $x[2]
			If $y = 18 And $iResizeMethod = "" Then $iResizeMethod = $x[2]
			If $y = 19 And $sOffsetX = "" Then $sOffsetX = $x[2]
			If $y = 20 And $sOffsetY = "" Then $sOffsetY = $x[2]
		Next
		If ($y = -1) Then Return SetError(1, -1, _MsgBoxError($x[1] & '=' & $x[2], _ArrayToString($aSearch, @TAB & 'or' & @TAB, 1, 18), $x[1] & '=' & $x[2]))
	EndIf
	If ($sTimeout = Default) Or ($sTimeout = "") Then $sTimeout = 0
	If ($sDefaultButton = Default) Or ($sDefaultButton = "") Then $sDefaultButton = 0
	If ($iButtonWidth = Default) Or ($iButtonWidth = "") Then $iButtonWidth = 100
	If ($iButtonHeight = Default) Or ($iButtonHeight = "") Then $iButtonHeight = 30
	If ($iButtonSeperator = Default) Or ($iButtonSeperator = "") Then $iButtonSeperator = 15
	If ($iLeftRightSpace = Default) Or ($iLeftRightSpace = "") Then $iLeftRightSpace = 15
	If ($iButtonBottomSpace = Default) Or ($iButtonBottomSpace = "") Then $iButtonBottomSpace = 15
	If ($sButtonStyle = Default) Or ($sButtonStyle = "") Then $sButtonStyle = 0
	If ($iLabelTopBottomSpace = Default) Or ($iLabelTopBottomSpace = "") Then $iLabelTopBottomSpace = 15
	If ($sLabelStyle = Default) Or ($sLabelStyle = "") Then $sLabelStyle = 0
	If ($iTransparency = Default) Or ($iTransparency = "") Then $iTransparency = 0
	If ($sIcon = Default) Or ($sIcon = "") Then $sIcon = 1
	If ($iResizeMethod = Default) Or ($iResizeMethod = "") Then $iResizeMethod = 1
	If ($s_MsgBoxBkClr = Default) Or ($s_MsgBoxBkClr = "") Then $s_MsgBoxBkClr = 0
	If ($sButtonBkClr = Default) Or ($sButtonBkClr = "") Then $sButtonBkClr = 0
	If ($sButtonTxClr = Default) Or ($sButtonTxClr = "") Then $sButtonTxClr = 0
	If ($sLabelBkClr = Default) Or ($sLabelBkClr = "") Then $sLabelBkClr = 0
	If ($sLabelTxClr = Default) Or ($sLabelTxClr = "") Then $sLabelTxClr = 0
	If IsInt($sButtons) Or ($sButtons = Default) Or ($sButtons = "") Then
		If ($sButtons > 6) Or ($sButtons < 0) And ($sButtons <> Default) Then
			Return SetError(1, -1, _MsgBoxError("$sButtons", '0-6 or own Buttons like: "Yes;No"', $sButtons))
		Else
			If ($sButtons = 0) Or ($sButtons = Default) Or ($sButtons = "") Then $sButtons = "OK"
			If ($sButtons = 1) Then $sButtons = "OK;Cancel"
			If ($sButtons = 2) Then $sButtons = "Abort;Retry;Ignore"
			If ($sButtons = 3) Then $sButtons = "Yes;No;Cancel"
			If ($sButtons = 4) Then $sButtons = "Yes;No"
			If ($sButtons = 5) Then $sButtons = "Retry;Cancel"
			If ($sButtons = 6) Then $sButtons = "Cancel;Try Again;Continue"
		EndIf
	EndIf
	Local $aButton_ = StringSplit($sButtons, ";")
	If ($sDefaultButton <> 0) Or Not StringIsDigit($sDefaultButton) Then
		For $i = 1 To $aButton_[0]
			If ($aButton_[$i] = $sDefaultButton) Or ($i = $sDefaultButton) Then ExitLoop
		Next
		If ($i >= $aButton_[0] + 1) Then
			Return SetError(1, -1, _MsgBoxError("$sDefaultButton", 'Choose one of your Buttons: ' & @LF & _ArrayToString($aButton_, @LF, 1), $sDefaultButton))
		EndIf
		$sDefaultButton = $i
	EndIf
	If StringInStr($sTimeout, ",") Or Not StringIsDigit($sTimeout) Then
		Local $aTimeout_ = StringSplit($sTimeout, ",")
		If $aTimeout_[0] <> 2 Or Not StringIsDigit($aTimeout_[2]) Then
			Return SetError(1, -1, _MsgBoxError("$sTimeout", '10 or "10" or "1,10" or "Yes,10". Default=0', $sTimeout))
		Else
			For $i = 1 To $aButton_[0]
				If $aButton_[$i] = $aTimeout_[1] Or $i = $aTimeout_[1] Then ExitLoop
			Next
			If ($i > $aButton_[0]) Then
				Return SetError(1, -1, _MsgBoxError("$sTimeoutButton", 'Choose one of your Buttons: ' & @LF & _ArrayToString($aButton_, @LF, 1), $aTimeout_[1]))
			Else
				Local $sTimeoutButton = $i
				$sTimeout = $aTimeout_[2]
			EndIf
		EndIf
	EndIf
	If ($sTimeout <> 0) Then
		Local $sTimeoutInit = TimerInit()
		Local $sTimeoutInitVar = TimerInit()
		Local $sTimeoutMs = $sTimeout * 1000
		$sTimeout -= 1
	EndIf
	If Not StringIsDigit($iButtonWidth) Then
		Return SetError(1, -1, _MsgBoxError("$iButtonWidth", 'Choose a number. Default=100', $iButtonWidth))
	ElseIf Not StringIsDigit($iButtonHeight) Then
		Return SetError(1, -1, _MsgBoxError("$iButtonHeight", 'Choose a number. Default=30', $iButtonHeight))
	ElseIf Not StringIsDigit($iButtonSeperator) Then
		Return SetError(1, -1, _MsgBoxError("$iButtonSeperator", 'Choose a number. Default=15', $iButtonSeperator))
	ElseIf Not StringIsDigit($iLeftRightSpace) Then
		Return SetError(1, -1, _MsgBoxError("$iLeftRightSpace", 'Choose a number. Default=15', $iLeftRightSpace))
	ElseIf Not StringIsDigit($iButtonBottomSpace) Then
		Return SetError(1, -1, _MsgBoxError("$iButtonBottomSpace", 'Choose a number. Default=15', $iButtonBottomSpace))
	EndIf
	If ($sButtonStyle < 0) Or ($sButtonStyle > 6) Or Not StringIsDigit($sButtonStyle) Then
		If ($sButtonStyle <> "Center") And ($sButtonStyle <> "Bottom") And ($sButtonStyle <> "Multiline") And ($sButtonStyle <> "Top") And ($sButtonStyle <> "VCenter") And ($sButtonStyle <> "Flat") Then Return SetError(1, -1, _MsgBoxError("$sButtonStyle", 'Choose a Style: 1-6' & @LF & '"Center" "Bottom" "Multiline" "Top" "VCenter" "Flat"', $sButtonStyle))
		If ($sButtonStyle = "Center") Or ($sButtonStyle = 1) Then $sButtonStyle = $BS_CENTER
		If ($sButtonStyle = "Bottom") Or ($sButtonStyle = 2) Then $sButtonStyle = $BS_BOTTOM
		If ($sButtonStyle = "Multiline") Or ($sButtonStyle = 3) Then $sButtonStyle = $BS_MULTILINE
		If ($sButtonStyle = "Top") Or ($sButtonStyle = 4) Then $sButtonStyle = $BS_TOP
		If ($sButtonStyle = "VCenter") Or ($sButtonStyle = 5) Then $sButtonStyle = $BS_VCENTER
		If ($sButtonStyle = "Flat") Or ($sButtonStyle = 6) Then $sButtonStyle = $BS_FLAT
	EndIf
	If Not StringIsDigit($iLabelTopBottomSpace) Then Return SetError(1, -1, _MsgBoxError("$iLabelTopBottomSpace", 'Choose a number. Default=15', $iLabelTopBottomSpace))
	If ($sLabelStyle < 0) Or ($sLabelStyle > 3) Or Not StringIsDigit($sLabelStyle) Then
		If $sLabelStyle <> "Center" And $sLabelStyle <> "Right" And $sLabelStyle <> "Sunken" Then
			Return SetError(1, -1, _MsgBoxError("$sButtonStyle", 'Choose a Style: 1-3' & @LF & '"Center" "Right" "Sunken"', $sButtonStyle))
		EndIf
		If $sLabelStyle = "Center" Then $sLabelStyle = 1
		If $sLabelStyle = "Right" Then $sLabelStyle = 2
		If $sLabelStyle = "Sunken" Or $sLabelStyle = 3 Then $sLabelStyle = 4096
		If $sLabelStyle = 0 Then $sLabelStyle = -1
	EndIf
	If ($s_MsgBoxBkClr <> "0") And Not StringRegExp($s_MsgBoxBkClr, '^0x[[:xdigit:]]+$') Then Return SetError(1, -1, _MsgBoxError("$s_MsgBoxBkClr", 'Choose a hex color code, like: 0x00FFFF.' & @LF & 'Default=0xFF0000 - Windows Classic Style.', $s_MsgBoxBkClr))
	If $sButtonBkClr <> "0" And Not StringRegExp($sButtonBkClr, '^0x[[:xdigit:]]+$') Then Return SetError(1, -1, _MsgBoxError("$sButtonBkClr", 'Choose a hex color code, like: 0x00FFFF.' & @LF & 'Default=0xFF0000 - Windows Classic Style.', $sButtonBkClr))
	If $sButtonTxClr <> "0" And Not StringRegExp($sButtonTxClr, '^0x[[:xdigit:]]+$') Then Return SetError(1, -1, _MsgBoxError("$sButtonTxClr", 'Choose a hex color code, like: 0x00FFFF.' & @LF & 'Default=0xFF0000 - Windows Classic Style.', $sButtonTxClr))
	If $sLabelBkClr <> "0" And Not StringRegExp($sLabelBkClr, '^0x[[:xdigit:]]+$') Then Return SetError(1, -1, _MsgBoxError("$sLabelBkClr", 'Choose a hex color code, like: 0x00FFFF.' & @LF & 'Default=0xFF0000 - Windows Classic Style.', $sLabelBkClr))
	If $sLabelTxClr <> "0" And Not StringRegExp($sLabelTxClr, '^0x[[:xdigit:]]+$') Then Return SetError(1, -1, _MsgBoxError("$sLabelTxClr", 'Choose a hex color code, like: 0x00FFFF.' & @LF & 'Default=0xFF0000 - Windows Classic Style.', $sLabelTxClr))
	If Not StringIsDigit($iTransparency) Or ($iTransparency < 0) Or ($iTransparency > 100) Then
		Return SetError(1, -1, _MsgBoxError("$iTransparency", 'Choose % 0 - 100. Default=0 > Solid.', $iTransparency))
	Else
		$iTransparency = (100 - $iTransparency) / 100 * 255
	EndIf
	If Not StringIsDigit($sIcon) Or ($sIcon < 0) Or ($sIcon > 1) Then
		If Not FileExists($sIcon) Or StringRight($sIcon, 4) <> ".ico" Then
			If ($sIcon <> 0) Or ($sIcon <> 1) Then
				Return SetError(1, -1, _MsgBoxError("$sIcon", 'Choose a valid .ico filepath.' & @LF & 'Default=1 or 0 for no icon.', $sIcon))
			EndIf
		EndIf
	EndIf
	If Not StringIsDigit($iResizeMethod) Or ($iResizeMethod < 1) Or ($iResizeMethod > 3) Then Return SetError(1, -1, _MsgBoxError("$iResizeMethod", 'ResizeMethod has to be a number.(1-3)-Default=1', $iTransparency))
	Local $iGUIWidth = $iLeftRightSpace + ($aButton_[0] * $iButtonWidth) + (($aButton_[0] - 1) * $iButtonSeperator) + $iLeftRightSpace + $sAddToWidth  ;Kim125er!
	Local $iMaxLabelWidth = $iGUIWidth - $iLeftRightSpace - $iLeftRightSpace
	Local $aLabelSize_ = _StringSize($sText, Default, Default, Default, Default, $iMaxLabelWidth) ;Kim125er!
	If @error = 3 Or $aLabelSize_[2] >= $iMaxLabelWidth Then
		$aLabelSize_ = _StringSize($sText, Default, Default, Default, Default)
		$iMaxLabelWidth = $aLabelSize_[2]
		$iGUIWidth = $iMaxLabelWidth + $iLeftRightSpace + $iLeftRightSpace
		Local $Resize
	EndIf
	Local $iGUIHeight = $iLabelTopBottomSpace + $aLabelSize_[3] + $iLabelTopBottomSpace + $iButtonHeight + $iButtonBottomSpace + $sAddToHeight ;kim125er!
	If ($sOffsetX = Default) Or ($sOffsetX = "") Then
		$sOffsetX = -1
	Else
		$sOffsetX = (@DesktopWidth / 2) - ($iGUIWidth / 2) + $sOffsetX
	EndIf
	If ($sOffsetY = Default) Or ($sOffsetY = "") Then
		$sOffsetY = -1
	Else
		$sOffsetY = @DesktopHeight / 2 - ($iGUIHeight / 2) + $sOffsetY
	EndIf
	Local $hGUI = GUICreate($sTitle, $iGUIWidth, $iGUIHeight, $sOffsetX, $sOffsetY, -1, $WS_EX_DLGMODALFRAME)
	If $s_MsgBoxBkClr <> 0 Then GUISetBkColor($s_MsgBoxBkClr, $hGUI)
	If $sIcon = 0 Then
		_WinAPI_DestroyIcon(_WinAPI_GetClassLongEx($hGUI, $GCL_HICON))
		_WinAPI_SetClassLongEx($hGUI, $GCL_HICON, 0)
		_WinAPI_SetClassLongEx($hGUI, $GCL_HICONSM, 0)
	ElseIf $sIcon = 1 Then
		Local $sWow64 = ""
		If @AutoItX64 Then $sWow64 = "\Wow6432Node"
		$sIcon = RegRead("HKEY_LOCAL_MACHINE\SOFTWARE" & $sWow64 & "\AutoIt v3\AutoIt", "InstallDir") & "\icons\au3.ico"
	EndIf
	If Not IsInt($sIcon) Then GUISetIcon($sIcon)
	GUICtrlCreateLabel($aLabelSize_[0], $iLeftRightSpace, $iLabelTopBottomSpace, $iMaxLabelWidth, $aLabelSize_[3], $sLabelStyle)
	If $sLabelBkClr <> 0 Then GUICtrlSetBkColor(-1, $sLabelBkClr)
	If $sLabelTxClr <> 0 Then GUICtrlSetColor(-1, $sLabelTxClr)
	If IsDeclared("Resize") Then
		If $iResizeMethod = 1 Then $iLeftRightSpace = (($iGUIWidth - ($aButton_[0] * $iButtonWidth) - (($aButton_[0] - 1) * $iButtonSeperator))) / 2
		If $iResizeMethod = 2 Then $iButtonWidth = ($iMaxLabelWidth - ($aButton_[0] - 1) * $iButtonSeperator) / $aButton_[0]
		If $iResizeMethod = 3 Then $iButtonSeperator = ($aLabelSize_[2] - ($aButton_[0] * $iButtonWidth)) / ($aButton_[0] - 1)
	EndIf
	Local $iButtonTop = $iLabelTopBottomSpace + $aLabelSize_[3] + $iLabelTopBottomSpace
	$First_Button = GUICtrlCreateDummy()
	For $i = 1 To $aButton_[0]
		$x = $iLeftRightSpace + (($i - 1) * $iButtonWidth) + (($i - 1) * $iButtonSeperator)
		If $i = $sDefaultButton Then
			If IsDeclared("sTimeoutButton") And $i = $sTimeoutButton Then
				Local $hTimeoutButton = GUICtrlCreateButton($aButton_[$i], $x, $iButtonTop, $iButtonWidth, $iButtonHeight, BitOR($BS_DEFPUSHBUTTON, $sButtonStyle))
			Else
				GUICtrlCreateButton($aButton_[$i], $x, $iButtonTop, $iButtonWidth, $iButtonHeight, BitOR($BS_DEFPUSHBUTTON, $sButtonStyle))
			EndIf
			$sDefaultBtnNo = $i
		Else
			If IsDeclared("sTimeoutButton") And $i = $sTimeoutButton Then
				Local $hTimeoutButton = GUICtrlCreateButton($aButton_[$i], $x, $iButtonTop, $iButtonWidth, $iButtonHeight, $sButtonStyle)
			Else
				GUICtrlCreateButton($aButton_[$i], $x, $iButtonTop, $iButtonWidth, $iButtonHeight, $sButtonStyle)
			EndIf
			If $sButtonBkClr <> 0 Then GUICtrlSetBkColor(-1, $sButtonBkClr)
			If $sButtonTxClr <> 0 Then GUICtrlSetColor(-1, $sButtonTxClr)
		EndIf
	Next
	$Last_Button = GUICtrlCreateDummy()
	GUISetState(@SW_SHOW, $hGUI)
	If $iTransparency <> 255 Then WinSetTrans($hGUI, "", $iTransparency)
	Local $iEventMode = Opt('GUIOnEventMode', 0)
	HotKeySet("{enter}", "_MsgBoxEnter")
	While 1
		$Msg = GUIGetMsg(0)
		Switch $Msg
			Case $GUI_EVENT_CLOSE
				GUIDelete($hGUI)
				Opt('GUIOnEventMode', $iEventMode)
				Return SetError(0, 0, _MsgBoxReturn("Closed-by-User", $tsButtons))

			Case $First_Button To $Last_Button
				For $i = 1 To $aButton_[0]
					If $aButton_[$i] = GUICtrlRead($Msg) Then ExitLoop
				Next
				GUIDelete($hGUI)
				Opt('GUIOnEventMode', $iEventMode)
				If $i > $aButton_[0] And IsDeclared("sTimeoutButton") Then
					Return SetError(0, $sTimeoutButton, _MsgBoxReturn($aButton_[$sTimeoutButton], $tsButtons))
				EndIf
				Return SetError(0, $i, _MsgBoxReturn($aButton_[$i], $tsButtons))
		EndSwitch
		If IsDeclared("sTimeoutInit") Then
			If TimerDiff($sTimeoutInit) >= $sTimeoutMs Then
				GUIDelete($hGUI)
				If IsDeclared("sOnEventMode") Then Opt("GUIOnEventMode", 0)
				If Not IsDeclared("sTimeoutButton") Then Return SetError(0, 0, _MsgBoxReturn("Closed-by-Timeout", $tsButtons))
				Return SetError(0, $sTimeoutButton, _MsgBoxReturn($aButton_[$sTimeoutButton], $tsButtons))
			Else
				If TimerDiff($sTimeoutInitVar) >= 1000 Then
					If Not IsDeclared("sTimeoutButton") Then
						WinSetTitle($hGUI, "", "[" & $sTimeout & "] - " & $sTitle)
					Else
						GUICtrlSetData($hTimeoutButton, $aButton_[$sTimeoutButton] & " [" & $sTimeout & "]")
					EndIf
					$sTimeout -= 1
					$sTimeoutInitVar = TimerInit()
				EndIf
			EndIf
		EndIf
		If $tMsgBoxEnter = 1 Then
			GUIDelete($hGUI)
			Opt('GUIOnEventMode', $iEventMode)
			Return SetError(0, $i, _MsgBoxReturn($aButton_[$sDefaultBtnNo], $tsButtons))
		EndIf
	WEnd
EndFunc   ;==>_MsgBox
Func _MsgBoxEnter()
	$tMsgBoxEnter = 1
EndFunc   ;==>_MsgBoxEnter
Func _MsgBoxReturn($stButton, $stButtons)
	If StringInStr($stButtons, ";") = 0 Then
		If $stButton = "OK" Then Return 1
		If $stButton = "Cancel" Then Return 2
		If $stButton = "Abort" Then Return 3
		If $stButton = "Retry" Then Return 4
		If $stButton = "Ignore" Then Return 5
		If $stButton = "Yes" Then Return 6
		If $stButton = "No" Then Return 7
		If $stButton = "Try Again" Then Return 10
		If $stButton = "Continue" Then Return 11
		If $stButton = "Closed-by-Timeout" Then Return -1
	EndIf
	HotKeySet("{enter}")
	Return $stButton
EndFunc   ;==>_MsgBoxReturn
Func _MsgBoxError($sParameter, $sDefault, $sValue)
	Local $Error = 'Error!' & @LF & @LF & 'Wrong Paramter: ' & @LF & $sParameter & @LF & @LF & 'Possible values: ' & @CR & $sDefault & @LF & @LF & 'Your Value: ' & $sValue
	If _MsgBox(4, "s_MsgBox Error", $Error & @CRLF & @CRLF & "Exit Script?") = 6 Then Exit
	Return $Error
EndFunc   ;==>_MsgBoxError
Func _StringSize($sText, $iSize = 8.5, $iWeight = 400, $iAttrib = 0, $sName = "", $iMaxWidth = 0, $hWnd = 0)
	If $iSize = Default Then $iSize = 8.5
	If $iWeight = Default Then $iWeight = 400
	If $iAttrib = Default Then $iAttrib = 0
	If $sName = "" Or $sName = Default Then $sName = _StringSize_DefaultFontName()
	If Not IsString($sText) Then Return SetError(1, 1, 0)
	If Not IsNumber($iSize) Then Return SetError(1, 2, 0)
	If Not IsInt($iWeight) Then Return SetError(1, 3, 0)
	If Not IsInt($iAttrib) Then Return SetError(1, 4, 0)
	If Not IsString($sName) Then Return SetError(1, 5, 0)
	If Not IsNumber($iMaxWidth) Then Return SetError(1, 6, 0)
	If Not IsHWnd($hWnd) And $hWnd <> 0 Then Return SetError(1, 7, 0)
	Local $aRet, $hDC, $hFont, $hLabel = 0, $hLabel_Handle
	Local $iExpTab = BitAND($iAttrib, 1)
	$iAttrib = BitAND($iAttrib, BitNOT(1))
	If IsHWnd($hWnd) Then
		$hLabel = GUICtrlCreateLabel("", -10, -10, 10, 10)
		$hLabel_Handle = GUICtrlGetHandle(-1)
		GUICtrlSetFont(-1, $iSize, $iWeight, $iAttrib, $sName)
		$aRet = DllCall("user32.dll", "handle", "GetDC", "hwnd", $hLabel_Handle)
		If @error Or $aRet[0] = 0 Then
			GUICtrlDelete($hLabel)
			Return SetError(2, 1, 0)
		EndIf
		$hDC = $aRet[0]
		$aRet = DllCall("user32.dll", "lparam", "SendMessage", "hwnd", $hLabel_Handle, "int", 0x0031, "wparam", 0, "lparam", 0) ; $WM_GetFont
		If @error Or $aRet[0] = 0 Then
			GUICtrlDelete($hLabel)
			Return SetError(2, _StringSize_Error_Close(2, $hDC), 0)
		EndIf
		$hFont = $aRet[0]
	Else
		$aRet = DllCall("user32.dll", "handle", "GetDC", "hwnd", $hWnd)
		If @error Or $aRet[0] = 0 Then Return SetError(2, 1, 0)
		$hDC = $aRet[0]
		$aRet = DllCall("gdi32.dll", "int", "GetDeviceCaps", "handle", $hDC, "int", 90) ; $LOGPIXELSY
		If @error Or $aRet[0] = 0 Then Return SetError(2, _StringSize_Error_Close(3, $hDC), 0)
		Local $iInfo = $aRet[0]
		$aRet = DllCall("gdi32.dll", "handle", "CreateFontW", "int", -$iInfo * $iSize / 72, "int", 0, "int", 0, "int", 0, _
				"int", $iWeight, "dword", BitAND($iAttrib, 2), "dword", BitAND($iAttrib, 4), "dword", BitAND($iAttrib, 8), "dword", 0, "dword", 0, _
				"dword", 0, "dword", 5, "dword", 0, "wstr", $sName)
		If @error Or $aRet[0] = 0 Then Return SetError(2, _StringSize_Error_Close(4, $hDC), 0)
		$hFont = $aRet[0]
	EndIf
	$aRet = DllCall("gdi32.dll", "handle", "SelectObject", "handle", $hDC, "handle", $hFont)
	If @error Or $aRet[0] = 0 Then Return SetError(2, _StringSize_Error_Close(5, $hDC, $hFont, $hLabel), 0)
	Local $hPrevFont = $aRet[0]
	Local $avSize_Info[4], $iLine_Length, $iLine_Height = 0, $iLine_Count = 0, $iLine_Width = 0, $iWrap_Count, $iLast_Word, $sTest_Line
	Local $tSize = DllStructCreate("int X;int Y")
	DllStructSetData($tSize, "X", 0)
	DllStructSetData($tSize, "Y", 0)
	$sText = StringRegExpReplace($sText, "((?<!\x0d)\x0a|\x0d(?!\x0a))", @CRLF)
	Local $asLines = StringSplit($sText, @CRLF, 1)
	For $i = 1 To $asLines[0]
		If $iExpTab Then $asLines[$i] = StringReplace($asLines[$i], @TAB, " XXXXXXXX")
		$iLine_Length = StringLen($asLines[$i])
		DllCall("gdi32.dll", "bool", "GetTextExtentPoint32W", "handle", $hDC, "wstr", $asLines[$i], "int", $iLine_Length, "ptr", DllStructGetPtr($tSize))
		If @error Then Return SetError(2, _StringSize_Error_Close(6, $hDC, $hFont, $hLabel), 0)
		If DllStructGetData($tSize, "X") > $iLine_Width Then $iLine_Width = DllStructGetData($tSize, "X")
		If DllStructGetData($tSize, "Y") > $iLine_Height Then $iLine_Height = DllStructGetData($tSize, "Y")
	Next
	If $iMaxWidth <> 0 And $iLine_Width > $iMaxWidth Then ; Wrapping required
		For $j = 1 To $asLines[0]
			$iLine_Length = StringLen($asLines[$j])
			DllCall("gdi32.dll", "bool", "GetTextExtentPoint32W", "handle", $hDC, "wstr", $asLines[$j], "int", $iLine_Length, "ptr", DllStructGetPtr($tSize))
			If @error Then Return SetError(2, _StringSize_Error_Close(6, $hDC, $hFont, $hLabel), 0)
			If DllStructGetData($tSize, "X") < $iMaxWidth - 4 Then
				$iLine_Count += 1
				$avSize_Info[0] &= $asLines[$j] & @CRLF
			Else
				$iWrap_Count = 0
				While 1
					$iLine_Width = 0
					$iLast_Word = 0
					For $i = 1 To StringLen($asLines[$j])
						If StringMid($asLines[$j], $i, 1) = " " Then $iLast_Word = $i - 1
						$sTest_Line = StringMid($asLines[$j], 1, $i)
						$iLine_Length = StringLen($sTest_Line)
						DllCall("gdi32.dll", "bool", "GetTextExtentPoint32W", "handle", $hDC, "wstr", $sTest_Line, "int", $iLine_Length, "ptr", DllStructGetPtr($tSize))
						If @error Then Return SetError(2, _StringSize_Error_Close(6, $hDC, $hFont, $hLabel), 0)
						$iLine_Width = DllStructGetData($tSize, "X")
						If $iLine_Width >= $iMaxWidth - 4 Then ExitLoop
					Next
					If $i > StringLen($asLines[$j]) Then
						$iWrap_Count += 1
						$avSize_Info[0] &= $sTest_Line & @CRLF
						ExitLoop
					Else
						$iWrap_Count += 1
						If $iLast_Word = 0 Then Return SetError(3, _StringSize_Error_Close(0, $hDC, $hFont, $hLabel), 0)
						$avSize_Info[0] &= StringLeft($sTest_Line, $iLast_Word) & @CRLF
						$asLines[$j] = StringTrimLeft($asLines[$j], $iLast_Word)
						$asLines[$j] = StringStripWS($asLines[$j], 1)
					EndIf
				WEnd
				$iLine_Count += $iWrap_Count
			EndIf
		Next
		If $iExpTab Then $avSize_Info[0] = StringRegExpReplace($avSize_Info[0], "\x20?XXXXXXXX", @TAB)
		$avSize_Info[1] = $iLine_Height
		$avSize_Info[2] = $iMaxWidth
		$avSize_Info[3] = ($iLine_Count * $iLine_Height) + 4
	Else
		Local $avSize_Info[4] = [$sText, $iLine_Height, $iLine_Width, ($asLines[0] * $iLine_Height) + 4]
	EndIf
	DllCall("gdi32.dll", "handle", "SelectObject", "handle", $hDC, "handle", $hPrevFont)
	DllCall("gdi32.dll", "bool", "DeleteObject", "handle", $hFont)
	DllCall("user32.dll", "int", "ReleaseDC", "hwnd", 0, "handle", $hDC)
	If $hLabel Then GUICtrlDelete($hLabel)
	Return $avSize_Info
EndFunc   ;==>_StringSize
Func _StringSize_Error_Close($iExtCode, $hDC = 0, $hFont = 0, $hLabel = 0)
	If $hFont <> 0 Then DllCall("gdi32.dll", "bool", "DeleteObject", "handle", $hFont)
	If $hDC <> 0 Then DllCall("user32.dll", "int", "ReleaseDC", "hwnd", 0, "handle", $hDC)
	If $hLabel Then GUICtrlDelete($hLabel)
	Return $iExtCode
EndFunc   ;==>_StringSize_Error_Close
Func _StringSize_DefaultFontName()
	Local $tNONCLIENTMETRICS = DllStructCreate("uint;int;int;int;int;int;byte[60];int;int;byte[60];int;int;byte[60];byte[60];byte[60]")
	DllStructSetData($tNONCLIENTMETRICS, 1, DllStructGetSize($tNONCLIENTMETRICS))
	DllCall("user32.dll", "int", "SystemParametersInfo", "int", 41, "int", DllStructGetSize($tNONCLIENTMETRICS), "ptr", DllStructGetPtr($tNONCLIENTMETRICS), "int", 0)
	Local $tLOGFONT = DllStructCreate("long;long;long;long;long;byte;byte;byte;byte;byte;byte;byte;byte;char[32]", DllStructGetPtr($tNONCLIENTMETRICS, 13))
	If IsString(DllStructGetData($tLOGFONT, 14)) Then
		Return DllStructGetData($tLOGFONT, 14)
	Else
		Return "Tahoma"
	EndIf
EndFunc   ;==>_StringSize_DefaultFontName
#EndRegion _MsgBox
Func Help()
EndFunc   ;==>Help

#Region ;**** Create Tray ****
Func _StartTray()
	Opt("TrayMenuMode", 3) ; The default tray menu items will not be shown and items are not checked when selected. These are options 1 and 2 for TrayMenuMode.
	Opt("TrayOnEventMode", 1)
	Local $iTrayOpenConfig = TrayCreateItem("Open Config")
	TrayItemSetOnEvent(-1, "TrayOpenConfig")
	Local $iTrayOpenLog = TrayCreateItem("Open Log")
	TrayItemSetOnEvent(-1, "TrayOpenLog")
	TrayCreateItem("") ; Create a separator line.
	Local $iTrayForceForecastUpdate = TrayCreateItem("Force a Forcast Update")
	TrayItemSetOnEvent(-1, "TrayForceForecastUpdate")
	Local $iTrayCopyToClipboard = TrayCreateItem("Copy Forecast to Clipboard")
	TrayItemSetOnEvent(-1, "TrayCopyToClipboard")
	Local $iTrayAbout = TrayCreateItem("About")
	TrayItemSetOnEvent(-1, "TrayAbout")
	TrayCreateItem("") ; Create a separator line.
	Local $iTrayRestartUtil = TrayCreateItem("Restart Util")
	TrayItemSetOnEvent(-1, "TrayRestartUtil")
	TrayCreateItem("") ; Create a separator line.
	Local $iTrayExit = TrayCreateItem("Exit")
	TrayItemSetOnEvent(-1, "TrayExit")
	TraySetState($TRAY_ICONSTATE_SHOW) ; Show the tray menu.
EndFunc   ;==>_StartTray
Func TrayOpenConfig()
	ShellExecute($aIniFile)
EndFunc   ;==>TrayOpenConfig
Func TrayOpenLog()
	ShellExecute($aLogFile)
EndFunc   ;==>TrayOpenLog
Func TrayCopyToClipboard()
	ClipPut($sReport)
EndFunc
Func TrayAbout()
	MsgBox($MB_SYSTEMMODAL, $aUtilName, $aUtilName & @CRLF & "Version: " & $aUtilVersion & @CRLF & @CRLF & "Install Path: " & @ScriptDir & @CRLF & @CRLF & "Discord: http://discord.gg/EU7pzPs" & @CRLF & "Website: http://www.phoenix125.com", 15)
EndFunc   ;==>TrayAbout
Func TrayForceForecastUpdate()
	SplashOff()
	_Splash("Forcing A Forecast Update . . .")
	Sleep(1000)
	FileDelete($CACHEFILE)
	_RestartUtil()
EndFunc   ;==>TrayForceForecastUpdate
Func TrayRestartUtil()
	_RestartUtil()
EndFunc   ;==>TrayRestartUtil
Func TrayExit()
	_ExitUtil()
EndFunc   ;==>TrayExit
Func _RestartUtil()
	SplashOff()
	_Splash("Restarting . . .")
	Sleep(1000)
	If @Compiled = 1 Then
		Run(FileGetShortName(@ScriptFullPath))
	Else
		Run(FileGetShortName(@AutoItExe) & ' "' & FileGetShortName(@ScriptFullPath) & '"')
	EndIf
	Exit
EndFunc   ;==>_RestartUtil
#EndRegion ;**** Create Tray ****

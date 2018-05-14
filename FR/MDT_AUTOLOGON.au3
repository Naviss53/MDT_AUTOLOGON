;===============================================================================
;
; Programme:        MDT_AUTOLOGON
; Description:      Programme d'ouverture de session automatique Windows pour MDT.
; Pré-requis:       Powershell
; Version:          1.0
;
; Auteur(s):        Naviss53
;
;===============================================================================
#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=MDT_AUTOLOGON.ico
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include <AutoItConstants.au3>
#include <MsgBoxConstants.au3>
#include <WinAPIShPath.au3>
#include <Array.au3>


;Ce script AutoIT a pour objectif d'effectuer des actions (ajouter des clé de registes d'autologin dans ce cas) après la fin du process de déploiement MDT
;car les clés de registres d'autologin sont automatiquement nettoyées par le script LTICleanup de MDT et nous empêche de mettre un poste en mode kiosque par exemple.


;Affectation des différents process MDT à monitorer lors d'un déploiement
$PID = ProcessExists("TSProgressUI.exe") ; Retournera le PID ou 0 si le processus n'existe pas
$PID2 = ProcessExists("mshta.exe") ; Retournera le PID ou 0 si le processus n'existe pas
$PID3 = ProcessExists("cscript.exe") ; Retournera le PID ou 0 si le processus n'existe pas

Global $HKLM
Global $User
Global $Password
Global $Domain
Global $Temp
Local $i = 5

;Utilisation de cette méthode de récupération de paramètres de ligne de commande pour des problèmes avec les double quotes
Local $aCmdLine = _WinAPI_CommandLineToArgv($CmdLineRaw)

;Affichage du tableau de paramètres récupérés dans la ligne de commandes
;_ArrayDisplay($aCmdLine)

;Recuperation des arguments d'auto login (user + password)
If (($aCmdLine[0] < 2) Or ($aCmdLine[0] > 3)) Then
	MsgBox($MB_ICONERROR, "ERREUR", "Erreur : Utilisation du programme incorrecte !" & @CRLF & @CRLF & @ScriptName & " <param_user> <param_password> <param_domain>" & @CRLF & @CRLF & "<param_domain> pas obligatoire si ouverture de compte local du poste.")
	Exit
Else
	$User = $aCmdLine[1]
	$Password = $aCmdLine[2]
	$Domain = @ComputerName

	If ($aCmdLine[0] = 3) Then
		$Domain = $aCmdLine[3]
	EndIf

EndIf

;Affectation de la hive HKLM selon que l'OS est 32 ou 64 bits
If (@OSArch <> "X64") Then
	$HKLM = "HKLM"
Else
	$HKLM = "HKLM64"
EndIf

;Création boucle WHILE
$loop = 0

While $loop = 0
   ;Verification si un des processus MDT existe. Si c'est le cas on pause 250ms et on recommence la vérification
	If (($PID <> 0) OR ($PID2 <> 0) OR ($PID3 <> 0)) Then
		sleep(250)
		$PID = ProcessExists("TSProgressUI.exe") ; Retournera le PID ou 0 si le processus n'existe pas
		$PID2 = ProcessExists("mshta.exe") ; Retournera le PID ou 0 si le processus n'existe pas
		$PID3 = ProcessExists("cscript.exe") ; Retournera le PID ou 0 si le processus n'existe pas
	Else
		;Si aucun de ces processus n'existent encore, cela signifie que le déploiement MDT est terminé
		;Attente de 5s pour être sûr que le process de nettoyage de MDT soit bien terminé.  (possibilité de supprimer cette ligne de code)
		;MsgBox($MB_ICONINFORMATION, "Attente post MDT", "Veuillez patienter avant l'application des paramètres post MDT !", 5)

		SplashTextOn("Attente post MDT", "Veuillez patientez " & $i & " seconde(s) avant l'application des paramètres post MDT !", 800, 42)
		For $i=5 To 1 Step -1
			ControlSetText("Attente post MDT", "", "Static1", "Veuillez patientez " & $i & " seconde(s) avant l'application des paramètres post MDT !")
			sleep(1000)
		Next

		SplashTextOn("En cours...", "Paramètres post MDT en cours d'application...", 800, 42)


		RegWrite($HKLM & "\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon", "AutoAdminLogon", "REG_SZ", "1")
		RegWrite($HKLM & "\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon", "DefaultUserName", "REG_SZ", $User)

		;Regarde si la clé de registre existe déjà.
		RegRead($HKLM & "\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon", "DefaultPassword")
		$Temp = @error
		;@error est défini à -1 lors de la lecture d'une valeur de clé de registre qui n'existe pas.
		If ($Temp = 0) Then
			;Supprime la clé de registre 'AutoLogonCount' qui bloque l'autologin
			RegDelete($HKLM & "\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon", "DefaultPassword")
		EndIf

		_SecureStorePassword()
		RegWrite($HKLM & "\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon", "DefaultDomainName", "REG_SZ", $Domain)

		sleep(250)

		;Regarde si la clé de registre existe déjà.
		RegRead($HKLM & "\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon", "AutoLogonCount")
		$Temp = @error
		;@error est défini à -1 lors de la lecture d'une valeur de clé de registre qui n'existe pas.
		If ($Temp = 0) Then
			;Supprime la clé de registre 'AutoLogonCount' qui bloque l'autologin
			RegDelete($HKLM & "\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon", "AutoLogonCount")
		EndIf

		$loop = 1
		SplashTextOn("Fin post MDT", "Application des paramètres post MDT terminée ! (" & $i & ")", 800, 42)
		For $i=5 To 1 Step -1
			ControlSetText("Fin post MDT", "", "Static1", "Application des paramètres post MDT terminée ! (" & $i & ")")
			sleep(1000)
		Next
	EndIf
WEnd


Func _SecureStorePassword()
	;Mise en variable du code C# pour réaliser un platform invoke de la fonction LSA LsaStorePrivateData
	Local $PInvokeLSAFunc = "Add-Type @'" & @CRLF & _
								"using System;" & @CRLF & _
								"using System.Collections.Generic;" & @CRLF & _
								"using System.Text;" & @CRLF & _
								"using System.Runtime.InteropServices;" & @CRLF & @CRLF & _
								"namespace ComputerSystem" & @CRLF & _
								"{" & @CRLF & _
									"public class LSAutil" & @CRLF & _
									"{" & @CRLF & _
										"[StructLayout(LayoutKind.Sequential)]" & @CRLF & _
										"private struct LSA_UNICODE_STRING" & @CRLF & _
										"{" & @CRLF & _
											"public UInt16 Length;" & @CRLF & _
											"public UInt16 MaximumLength;" & @CRLF & _
											"public IntPtr Buffer;" & @CRLF & _
										"}" & @CRLF & @CRLF & _
										"[StructLayout(LayoutKind.Sequential)]" & @CRLF & _
										"private struct LSA_OBJECT_ATTRIBUTES" & @CRLF & _
										"{" & @CRLF & _
											"public int Length;" & @CRLF & _
											"public IntPtr RootDirectory;" & @CRLF & _
											"public LSA_UNICODE_STRING ObjectName;" & @CRLF & _
											"public uint Attributes;" & @CRLF & _
											"public IntPtr SecurityDescriptor;" & @CRLF & _
											"public IntPtr SecurityQualityOfService;" & @CRLF & _
										"}" & @CRLF & @CRLF & _
										"private enum LSA_AccessPolicy : long" & @CRLF & _
										"{" & @CRLF & _
											"POLICY_VIEW_LOCAL_INFORMATION = 0x00000001L," & @CRLF & _
											"POLICY_VIEW_AUDIT_INFORMATION = 0x00000002L," & @CRLF & _
											"POLICY_GET_PRIVATE_INFORMATION = 0x00000004L," & @CRLF & _
											"POLICY_TRUST_ADMIN = 0x00000008L," & @CRLF & _
											"POLICY_CREATE_ACCOUNT = 0x00000010L," & @CRLF & _
											"POLICY_CREATE_SECRET = 0x00000020L," & @CRLF & _
											"POLICY_CREATE_PRIVILEGE = 0x00000040L," & @CRLF & _
											"POLICY_SET_DEFAULT_QUOTA_LIMITS = 0x00000080L," & @CRLF & _
											"POLICY_SET_AUDIT_REQUIREMENTS = 0x00000100L," & @CRLF & _
											"POLICY_AUDIT_LOG_ADMIN = 0x00000200L," & @CRLF & _
											"POLICY_SERVER_ADMIN = 0x00000400L," & @CRLF & _
											"POLICY_LOOKUP_NAMES = 0x00000800L," & @CRLF & _
											"POLICY_NOTIFICATION = 0x00001000L" & @CRLF & _
										"}" & @CRLF & @CRLF & _
										"[DllImport(" & chr(34) & "advapi32.dll" & chr(34) &", SetLastError = true, PreserveSig = true)]" & @CRLF & _
										"private static extern uint LsaRetrievePrivateData(" & @CRLF & _
													"IntPtr PolicyHandle," & @CRLF & _
													"ref LSA_UNICODE_STRING KeyName," & @CRLF & _
													"out IntPtr PrivateData" & @CRLF & _
										");" & @CRLF & @CRLF & _
										"[DllImport(" & chr(34) & "advapi32.dll" & chr(34) & ", SetLastError = true, PreserveSig = true)]" & @CRLF & _
										"private static extern uint LsaStorePrivateData(" & @CRLF & _
												"IntPtr policyHandle," & @CRLF & _
												"ref LSA_UNICODE_STRING KeyName," & @CRLF & _
												"ref LSA_UNICODE_STRING PrivateData" & @CRLF & _
										");" & @CRLF & @CRLF & _
										"[DllImport(" & chr(34) & "advapi32.dll" & chr(34) & ", SetLastError = true, PreserveSig = true)]" & @CRLF & _
										"private static extern uint LsaOpenPolicy(" & @CRLF & _
											"ref LSA_UNICODE_STRING SystemName," & @CRLF & _
											"ref LSA_OBJECT_ATTRIBUTES ObjectAttributes," & @CRLF & _
											"uint DesiredAccess," & @CRLF & _
											"out IntPtr PolicyHandle" & @CRLF & _
										");" & @CRLF & @CRLF & _
										"[DllImport(" & chr(34) & "advapi32.dll" & chr(34) & ", SetLastError = true, PreserveSig = true)]" & @CRLF & _
										"private static extern uint LsaNtStatusToWinError(" & @CRLF & _
											"uint status" & @CRLF & _
										");" & @CRLF & @CRLF & _
										"[DllImport(" & chr(34) & "advapi32.dll" & chr(34) & ", SetLastError = true, PreserveSig = true)]" & @CRLF & _
										"private static extern uint LsaClose(" & @CRLF & _
											"IntPtr policyHandle" & @CRLF & _
										");" & @CRLF & @CRLF & _
										"[DllImport(" & chr(34) & "advapi32.dll" & chr(34) & ", SetLastError = true, PreserveSig = true)]" & @CRLF & _
										"private static extern uint LsaFreeMemory(" & @CRLF & _
											"IntPtr buffer" & @CRLF & _
										");" & @CRLF & @CRLF & _
										"private LSA_OBJECT_ATTRIBUTES objectAttributes;" & @CRLF & _
										"private LSA_UNICODE_STRING localsystem;" & @CRLF & _
										"private LSA_UNICODE_STRING secretName;" & @CRLF & @CRLF & _
										"public LSAutil(string key)" & @CRLF & _
										"{" & @CRLF & _
											"if (key.Length == 0)" & @CRLF & _
											"{" & @CRLF & _
												"throw new Exception(" & chr(34) & "Key lenght zero" & chr(34) & ");" & @CRLF & _
											"}" & @CRLF & @CRLF & _
											"objectAttributes = new LSA_OBJECT_ATTRIBUTES();" & @CRLF & _
											"objectAttributes.Length = 0;" & @CRLF & _
											"objectAttributes.RootDirectory = IntPtr.Zero;" & @CRLF & _
											"objectAttributes.Attributes = 0;" & @CRLF & _
											"objectAttributes.SecurityDescriptor = IntPtr.Zero;" & @CRLF & _
											"objectAttributes.SecurityQualityOfService = IntPtr.Zero;" & @CRLF & @CRLF & _
											"localsystem = new LSA_UNICODE_STRING();" & @CRLF & _
											"localsystem.Buffer = IntPtr.Zero;" & @CRLF & _
											"localsystem.Length = 0;" & @CRLF & _
											"localsystem.MaximumLength = 0;" & @CRLF & @CRLF & _
											"secretName = new LSA_UNICODE_STRING();" & @CRLF & _
											"secretName.Buffer = Marshal.StringToHGlobalUni(key);" & @CRLF & _
											"secretName.Length = (UInt16)(key.Length * UnicodeEncoding.CharSize);" & @CRLF & _
											"secretName.MaximumLength = (UInt16)((key.Length + 1) * UnicodeEncoding.CharSize);" & @CRLF & _
										"}" & @CRLF & @CRLF & _
										"private IntPtr GetLsaPolicy(LSA_AccessPolicy access)" & @CRLF & _
										"{" & @CRLF & _
											"IntPtr LsaPolicyHandle;" & @CRLF & @CRLF & _
											"uint ntsResult = LsaOpenPolicy(ref this.localsystem, ref this.objectAttributes, (uint)access, out LsaPolicyHandle);" & @CRLF & @CRLF & _
											"uint winErrorCode = LsaNtStatusToWinError(ntsResult);" & @CRLF & _
											"if (winErrorCode != 0)" & @CRLF & _
											"{" & @CRLF & _
												"throw new Exception(" & chr(34) & "LsaOpenPolicy failed: " & chr(34) & " + winErrorCode);" & @CRLF & _
											"}" & @CRLF & @CRLF & _
											"return LsaPolicyHandle;" & @CRLF & _
										"}" & @CRLF & @CRLF & _
										"private static void ReleaseLsaPolicy(IntPtr LsaPolicyHandle)" & @CRLF & _
										"{" & @CRLF & _
											"uint ntsResult = LsaClose(LsaPolicyHandle);" & @CRLF & _
											"uint winErrorCode = LsaNtStatusToWinError(ntsResult);" & @CRLF & _
											"if (winErrorCode != 0)" & @CRLF & _
											"{" & @CRLF & _
												"throw new Exception(" & chr(34) & "LsaClose failed: " & chr(34) & " + winErrorCode);" & @CRLF & _
											"}" & @CRLF & _
										"}" & @CRLF & @CRLF & _
										"public void SetSecret(string value)" & @CRLF & _
										"{" & @CRLF & _
											"LSA_UNICODE_STRING lusSecretData = new LSA_UNICODE_STRING();" & @CRLF & @CRLF & _
											"if (value.Length > 0)" & @CRLF & _
											"{" & @CRLF & _
												"//Create data and key" & @CRLF & _
												"lusSecretData.Buffer = Marshal.StringToHGlobalUni(value);" & @CRLF & _
												"lusSecretData.Length = (UInt16)(value.Length * UnicodeEncoding.CharSize);" & @CRLF & _
												"lusSecretData.MaximumLength = (UInt16)((value.Length + 1) * UnicodeEncoding.CharSize);" & @CRLF & _
											"}" & @CRLF & _
											"else" & @CRLF & _
											"{" & @CRLF & _
												"//Delete data and key" & @CRLF & _
												"lusSecretData.Buffer = IntPtr.Zero;" & @CRLF & _
												"lusSecretData.Length = 0;" & @CRLF & _
												"lusSecretData.MaximumLength = 0;" & @CRLF & _
											"}" & @CRLF & @CRLF & _
											"IntPtr LsaPolicyHandle = GetLsaPolicy(LSA_AccessPolicy.POLICY_CREATE_SECRET);" & @CRLF & _
											"uint result = LsaStorePrivateData(LsaPolicyHandle, ref secretName, ref lusSecretData);" & @CRLF & _
											"ReleaseLsaPolicy(LsaPolicyHandle);" & @CRLF & @CRLF & _
											"uint winErrorCode = LsaNtStatusToWinError(result);" & @CRLF & _
											"if (winErrorCode != 0)" & @CRLF & _
											"{" & @CRLF & _
												"throw new Exception(" & chr(34) & "StorePrivateData failed: " & chr(34) & " + winErrorCode);" & @CRLF & _
											"}" & @CRLF & _
										"}" & @CRLF & _
									"}" & @CRLF & _
								"}" & @CRLF & _
							"'@;"


  	Local $PsCommandLSASetSecret = $PInvokeLSAFunc & @CRLF & _
										"Try { " & @CRLF & _
										"Set-Variable -Name lsaUtil -Value(New-Object ComputerSystem.LSAutil -ArgumentList '" & "DefaultPassword" & "');" & @CRLF & _
										"$lsaUtil.SetSecret(@'" & @CRLF & _
										$Password & @CRLF & _
										"'@" & @CRLF & _
										");" & @CRLF & _
										"} catch { exit 8888 }"
	;Permet la prise en compte des guillemets dans la fonction "run" d'autoit qui lance les commandes powershell dans powershell
	$PsCommandLSASetSecret = StringReplace($PsCommandLSASetSecret, '"', '"""')

	Local $CMD01 = EnvGet("SystemDrive") & "\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -command " & chr(34) & $PsCommandLSASetSecret & chr(34)
	Local $Pid01 = Run($CMD01, @ScriptDir, @SW_HIDE, $STDOUT_CHILD + $STDERR_CHILD)

	;Attente de la fin de la commande
	ProcessWaitClose($Pid01)
	Local $Handle01 = _ProcessExitCode($Pid01)
	;Local $Return_Text01 = ShowStdOutErr($Pid01)
	Local $ExitCode01 = _ProcessExitCode($Pid01, $Handle01)
	_ProcessCloseHandle($Handle01)
	StdioClose($Pid01)

	If ($ExitCode01 <> 0) Then
		MsgBox($MB_ICONERROR, "ERREUR", "Une erreur s'est produite durant le stockage du mot de passe sécurisé pour le mode kiosque !" & @CRLF & "Le mode kiosque ne peut aboutir !")
		Exit
	EndIf

	Return
EndFunc



Func _ProcessCloseHandle($h_Process)
	; Close the process handle of a PID
	DllCall('kernel32.dll', 'ptr', 'CloseHandle', 'ptr', $h_Process)
	If Not @error Then Return 1
	Return 0
EndFunc   ;==>_ProcessCloseHandle
;===============================================================================
;
; Function Name:    _ProcessExitCode()
; Description:      Returns a handle/exitcode from use of Run().
; Parameter(s):     $i_Pid        - ProcessID returned from a Run() execution
;                   $h_Process    - Process handle
; Requirement(s):   None
; Return Value(s):  On Success - Returns Process handle while Run() is executing
;                                (use above directly after Run() line with only PID parameter)
;                              - Returns Process Exitcode when Process does not exist
;                                (use above with PID and Process Handle parameter returned from first UDF call)
;                   On Failure - 0
; Author(s):        MHz (Thanks to DaveF for posting these DllCalls in Support Forum)
;
;===============================================================================
;
Func _ProcessExitCode($i_Pid, $h_Process = 0)
	; 0 = Return Process Handle of PID else use Handle to Return Exitcode of a PID
	Local $v_Placeholder
	If Not IsArray($h_Process) Then
		; Return the process handle of a PID
		$h_Process = DllCall('kernel32.dll', 'ptr', 'OpenProcess', 'int', 0x400, 'int', 0, 'int', $i_Pid)
		If Not @error Then Return $h_Process
	Else
		; Return Process Exitcode of PID
		$h_Process = DllCall('kernel32.dll', 'ptr', 'GetExitCodeProcess', 'ptr', $h_Process[0], 'int*', $v_Placeholder)
		If Not @error Then Return $h_Process[2]
	EndIf
	Return 0
EndFunc   ;==>_ProcessExitCode

; Get STDOUT and ERROUT from commandline tool
Func ShowStdOutErr($l_Handle, $ShowConsole = 1, $Replace = "", $ReplaceWith = "")
	Local $Line = "x", $Line2 = "x", $tot_out, $err1 = 0, $err2 = 0, $cnt1 = 0, $cnt2 = 0
	Do
		Sleep(10)
		$Line = StdoutRead($l_Handle)
		$err1 = @error
		If $Replace <> "" Then $Line = StringReplace($Line, $Replace, $ReplaceWith)
		$tot_out &= $Line
		If $ShowConsole Then ConsoleWrite($Line)
		$Line2 = StderrRead($l_Handle)
		$err2 = @error
		If $Replace <> "" Then $Line2 = StringReplace($Line2, $Replace, $ReplaceWith)
		$tot_out &= $Line2
		If $ShowConsole Then ConsoleWrite($Line2)
		; end the loop also when AutoIt3 has ended but a sub process was shelled with Run() that is still active
		; only do this every 50 cycles to avoid cpu hunger
		If $cnt1 = 50 Then
			$cnt1 = 0
			; loop another 50 times just to ensure the buffers emptied.
			If Not ProcessExists($l_Handle) Then
				If $cnt2 > 2 Then ExitLoop
				$cnt2 += 1
			EndIf
		EndIf
		$cnt1 += 1
	Until ($err1 And $err2)
	Return $tot_out
EndFunc   ;==>ShowStdOutErr

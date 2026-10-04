Unicode true
RequestExecutionLevel user
SetCompressor zlib
ShowInstDetails show

!include "MUI2.nsh"
!include "nsDialogs.nsh"
!include "LogicLib.nsh"

!ifndef STAGEDIR
  !error "STAGEDIR is required"
!endif

!define CURRENT_APP_VERSION "0.2.4"

Name "Wordleaf"
OutFile "Wordleaf-Windows-Installer.exe"
InstallDir "$LOCALAPPDATA\Programs\Wordleaf"

Var DriveDialog
Var DriveInfo
Var DriveSelected
Var DriveCount
Var InstallPathLabel

!define MUI_ABORTWARNING
Page custom DrivePage DrivePageLeave
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\writer.exe"
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

!macro DRIVE_OPTION INDEX Y
  ReadINIStr $0 "$DriveInfo" "Drive${INDEX}" "Root"
  ${If} $0 != ""
    ReadINIStr $1 "$DriveInfo" "Drive${INDEX}" "Display"
    ReadINIStr $4 "$DriveInfo" "Drive${INDEX}" "Recommended"
    ${If} $4 == "1"
      StrCpy $1 "$1  -  Recommended"
    ${EndIf}
    ${NSD_CreateRadioButton} 0 ${Y} 100% 12u "$1"
    Pop $2
    nsDialogs::SetUserData $2 "$0"
    ${NSD_OnClick} $2 DriveRadioClick
    ReadINIStr $3 "$DriveInfo" "Drive${INDEX}" "Default"
    ${If} $DriveCount == 0
      ${NSD_Check} $2
      StrCpy $DriveSelected "$0"
    ${EndIf}
    ${If} $3 == 1
      ${NSD_Check} $2
      StrCpy $DriveSelected "$0"
    ${EndIf}
    IntOp $DriveCount $DriveCount + 1
  ${EndIf}
!macroend

Function DrivePage
  InitPluginsDir
  StrCpy $DriveInfo "$PLUGINSDIR\foxmoss-drives.ini"
  StrCpy $DriveSelected ""
  StrCpy $DriveCount 0

  File /oname=$PLUGINSDIR\drive-options.ps1 "drive-options.ps1"
  nsExec::ExecToStack 'powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PLUGINSDIR\drive-options.ps1" -OutputPath "$DriveInfo" -CurrentInstallDir "$INSTDIR"'
  Pop $0
  Pop $1

  nsDialogs::Create 1018
  Pop $DriveDialog
  ${If} $DriveDialog == error
    Abort
  ${EndIf}

  !insertmacro MUI_HEADER_TEXT "Choose a drive" "Wordleaf will install on the drive you select."
  ${NSD_CreateLabel} 0 0 100% 24u "Choose one local writable drive. The option marked Recommended is chosen from this computer's detected storage hardware (NVMe/SSD/HDD/removable) and available space. Cloud, optical, virtual, and read-only targets are excluded."
  Pop $4

  !insertmacro DRIVE_OPTION 1 30u
  !insertmacro DRIVE_OPTION 2 43u
  !insertmacro DRIVE_OPTION 3 56u
  !insertmacro DRIVE_OPTION 4 69u
  !insertmacro DRIVE_OPTION 5 82u
  !insertmacro DRIVE_OPTION 6 95u
  !insertmacro DRIVE_OPTION 7 108u
  !insertmacro DRIVE_OPTION 8 121u
  !insertmacro DRIVE_OPTION 9 134u
  !insertmacro DRIVE_OPTION 10 147u

  ${If} $DriveCount == 0
    MessageBox MB_ICONSTOP "No writable local fixed drive was found."
    Abort
  ${EndIf}

  ${NSD_CreateLabel} 0 166u 100% 18u ""
  Pop $InstallPathLabel
  ${If} $DriveSelected != ""
    StrCpy $INSTDIR "$DriveSelected\Wordleaf"
    ${NSD_SetText} $InstallPathLabel "Install location: $INSTDIR"
  ${EndIf}

  nsDialogs::Show
FunctionEnd

Function DriveRadioClick
  Pop $0
  nsDialogs::GetUserData $0
  Pop $DriveSelected
  StrCpy $INSTDIR "$DriveSelected\Wordleaf"
  ${NSD_SetText} $InstallPathLabel "Install location: $INSTDIR"
FunctionEnd

Function DrivePageLeave
  ${If} $DriveSelected == ""
    MessageBox MB_ICONEXCLAMATION "Choose a drive for Wordleaf."
    Abort
  ${EndIf}
  StrCpy $INSTDIR "$DriveSelected\Wordleaf"
FunctionEnd

Section "Install"
  InitPluginsDir
  File /oname=$PLUGINSDIR\check-latest-installer.ps1 "check-latest-installer.ps1"
  DetailPrint "Checking for the newest Wordleaf release..."
  nsExec::ExecToLog /TIMEOUT=900000 'powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "$PLUGINSDIR\check-latest-installer.ps1" -CurrentVersion "${CURRENT_APP_VERSION}" -ReleaseRepo "FoxandMoss/WordLeaf-releases" -StableAssetName "Wordleaf-Windows-Installer.exe" -AppName "Wordleaf"'
  Pop $0
  ${If} $0 == "timeout"
    MessageBox MB_ICONSTOP "Wordleaf could not finish checking the newest release. Nothing has been installed yet."
    Abort
  ${ElseIf} $0 == 10
    DetailPrint "A newer Wordleaf installer was opened. Closing this older installer."
    Quit
  ${ElseIf} $0 == 20
    MessageBox MB_ICONSTOP "A newer Wordleaf release exists, but it could not be downloaded and verified safely. Nothing has been installed."
    Abort
  ${EndIf}

  InitPluginsDir
  File /oname=$PLUGINSDIR\cleanup-legacy.ps1 "cleanup-legacy.ps1"
  nsExec::ExecToLog 'powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "$PLUGINSDIR\cleanup-legacy.ps1" -App "Wordleaf" -KeepInstallDir "$INSTDIR"'

  SetOutPath "$INSTDIR"
  File /r "${STAGEDIR}\*.*"

  CreateDirectory "$INSTDIR\.foxmoss"
  SetOutPath "$INSTDIR\.foxmoss"
  File /oname=cleanup-legacy.ps1 "cleanup-legacy.ps1"

  SetOutPath "$INSTDIR"
  WriteUninstaller "$INSTDIR\uninstall.exe"

  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Wordleaf" "DisplayName" "Wordleaf"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Wordleaf" "DisplayVersion" "0.2.4.1"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Wordleaf" "Publisher" "Fox & Moss"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Wordleaf" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Wordleaf" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Wordleaf" "DisplayIcon" "$INSTDIR\writer.exe"

  CreateDirectory "$SMPROGRAMS\Fox & Moss"
  CreateShortcut "$SMPROGRAMS\Fox & Moss\Wordleaf.lnk" "$INSTDIR\writer.exe"
SectionEnd

Section "Uninstall"
  nsExec::ExecToLog 'powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "$INSTDIR\.foxmoss\cleanup-legacy.ps1" -App "Wordleaf" -KeepInstallDir ""'
  Delete "$SMPROGRAMS\Fox & Moss\Wordleaf.lnk"
  RMDir "$SMPROGRAMS\Fox & Moss"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Wordleaf"
  RMDir /r "$INSTDIR"
SectionEnd

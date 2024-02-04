Var newStartMenuLink
Var oldStartMenuLink
Var newDesktopLink
Var oldDesktopLink
Var oldShortcutName
Var oldMenuDirectory

!include "common.nsh"
!include "MUI2.nsh"
!include "multiUser.nsh"
!include "allowOnlyOneInstallerInstance.nsh"

!ifdef INSTALL_MODE_PER_ALL_USERS
  !ifdef BUILD_UNINSTALLER
    RequestExecutionLevel user
  !else
    RequestExecutionLevel admin
  !endif
!else
  RequestExecutionLevel user
!endif

!ifdef BUILD_UNINSTALLER
  SilentInstall silent
!else
  Var appExe
  Var launchLink
!endif

!ifdef ONE_CLICK
  !include "oneClick.nsh"
!else
  !include "assistedInstaller.nsh"
!endif

!insertmacro addLangs

!ifmacrodef customHeader
  !insertmacro customHeader
!endif

Function .onInit
  Call setInstallSectionSpaceRequired

  SetOutPath $INSTDIR
  ${LogSet} on

  !ifmacrodef preInit
    !insertmacro preInit
  !endif

  !ifdef DISPLAY_LANG_SELECTOR
    !insertmacro MUI_LANGDLL_DISPLAY
  !endif

  !ifdef BUILD_UNINSTALLER
    WriteUninstaller "${UNINSTALLER_OUT_FILE}"
    !insertmacro quitSuccess
  !else
    !insertmacro check64BitAndSetRegView

    ${IfNot} ${UAC_IsInnerInstance}
      !insertmacro ALLOW_ONLY_ONE_INSTALLER_INSTANCE
    ${EndIf}

    !insertmacro initMultiUser

    # If we're running a silent upgrade of a per-machine installation, elevate so extracting the new app will succeed.
    # For a non-silent install, the elevation will be triggered when the install mode is selected in the UI,
    # but that won't be executed when silent.
    !ifndef INSTALL_MODE_PER_ALL_USERS
      ${if} $hasPerMachineInstallation == "1" # set in onInit by initMultiUser
      !ifndef ONE_CLICK
        ${andIf} ${Silent}
      !endif
        ${ifNot} ${UAC_IsAdmin}
          !insertmacro UAC_RunElevated
          ${Switch} $0
            ${Case} 0
              ${Break}
            ${Case} 1223 ;user aborted
              ${Break}
            ${Default}
              MessageBox mb_IconStop|mb_TopMost|mb_SetForeground "Unable to elevate, error $0"
              ${Break}
          ${EndSwitch}
          Quit
        ${else}
          !insertmacro setInstallModePerAllUsers
        ${endIf}
      ${endIf}
      !ifdef ONE_CLICK
        !ifdef INSTALL_MODE_PER_ALL_USERS_DEFAULT
          ${if} $hasPerMachineInstallation == "0"
          ${andIf} $hasPerUserInstallation == "1"
            !insertmacro setInstallModePerUser
          ${endIf}
          ${if} $hasPerMachineInstallation == "0"
          ${andIf} $hasPerUserInstallation == "0"
            ${ifNot} ${UAC_IsAdmin}
              !insertmacro UAC_RunElevated
              ${Switch} $0
                ${Case} 0
                  Quit
                  ${Break}
                ${Default}
                  !insertmacro setInstallModePerUser
                  ${Break}
              ${EndSwitch}
            ${else}
              !insertmacro setInstallModePerAllUsers
            ${endIf}
          ${endIf}
        !endif
      !endif
    !endif

    !ifmacrodef customInit
      !insertmacro customInit
    !endif

    !ifmacrodef addLicenseFiles
      InitPluginsDir
      !insertmacro addLicenseFiles
    !endif
  !endif
FunctionEnd

!ifndef BUILD_UNINSTALLER
  !include "installUtil.nsh"
!endif

Section "install" INSTALL_SECTION_ID
  !ifndef BUILD_UNINSTALLER
    !include "installSection.nsh"
  !endif
SectionEnd

Function setInstallSectionSpaceRequired
  !insertmacro setSpaceRequired ${INSTALL_SECTION_ID}
FunctionEnd

!ifdef BUILD_UNINSTALLER
  !include "uninstaller.nsh"
!endif

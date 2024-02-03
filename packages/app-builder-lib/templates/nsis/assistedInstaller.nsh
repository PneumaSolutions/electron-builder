!include UAC.nsh

!ifndef INSTALL_MODE_PER_ALL_USERS
  !include multiUserUi.nsh
!endif

!ifndef BUILD_UNINSTALLER

  !ifmacrodef customWelcomePage
    !insertmacro customWelcomePage
  !endif

  !ifmacrodef licensePage
    !insertmacro skipPageIfUpdated
    !insertmacro licensePage
  !endif

  !ifndef INSTALL_MODE_PER_ALL_USERS
    !insertmacro PAGE_INSTALL_MODE
  !endif

  !ifdef allowToChangeInstallationDirectory
    !include StrContains.nsh

    !insertmacro skipPageIfUpdated
    !insertmacro MUI_PAGE_DIRECTORY

    # pageDirectory leave doesn't work (it seems because $INSTDIR is set after custom leave function)
    # so, we use instfiles pre
    !define MUI_PAGE_CUSTOMFUNCTION_PRE instFilesPre

    # sanitize the MUI_PAGE_DIRECTORY result to make sure it has a application name sub-folder
    Function instFilesPre
      ${StrContains} $0 "${APP_FILENAME}" $INSTDIR
      ${If} $0 == ""
        StrCpy $INSTDIR "$INSTDIR\${APP_FILENAME}"
      ${endIf}
    FunctionEnd
  !endif

  # after change installation directory and before install start, you can show custom page here.
  !ifmacrodef customPageAfterChangeDir
    !insertmacro customPageAfterChangeDir
  !endif

  !insertmacro MUI_PAGE_INSTFILES
  !ifmacrodef customFinishPage
    !insertmacro customFinishPage
  !else
    !ifndef HIDE_RUN_AFTER_FINISH
      Function StartApp
        ${if} ${isUpdated}
          StrCpy $1 "--updated"
        ${else}
          StrCpy $1 ""
        ${endif}
        ${StdUtils.ExecShellAsUser} $0 "$launchLink" "open" "$1"
      FunctionEnd

      !define MUI_FINISHPAGE_RUN
      !define MUI_FINISHPAGE_RUN_FUNCTION "StartApp"
    !endif
    !insertmacro MUI_PAGE_FINISH
  !endif
!else
  !ifndef removeDefaultUninstallWelcomePage
    !ifmacrodef customUnWelcomePage
      !insertmacro customUnWelcomePage
    !else
      !insertmacro MUI_UNPAGE_WELCOME
  !endif

  !endif
  !ifndef INSTALL_MODE_PER_ALL_USERS
    !insertmacro PAGE_INSTALL_MODE
  !endif
  !insertmacro MUI_UNPAGE_INSTFILES
  !ifmacrodef customUninstallPage
    !insertmacro customUninstallPage
  !endif
  !insertmacro MUI_UNPAGE_FINISH
!endif

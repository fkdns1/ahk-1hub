#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
DetectHiddenWindows True
SetWorkingDir A_ScriptDir

; =========================================================
; AHK Hub v2
; - One visible tray icon.
; - Click tray icon to open a dark popup panel.
; - Auto-loads *.ahk modules from the saved default folder on launch.
; - Folder picker button saves the module folder to AHK_Hub.ini.
; - Startup checkbox creates/removes a shortcut in the Windows Startup folder.
; - CPU-light design: no polling timer, no background scan loop.
;
; Notes:
; - Modules are launched through generated hidden runner files so their
;   tray icons are suppressed by #NoTrayIcon.
; - If a module behaves differently when wrapped, set USE_HIDDEN_RUNNERS := false
;   and add #NoTrayIcon directly at the top of that module.
; =========================================================

; -----------------------------
; User options
; -----------------------------
AUTO_START_MODULES_ON_LAUNCH := true   ; true = start every discovered module when Hub starts.
USE_HIDDEN_RUNNERS := true              ; true = generate #NoTrayIcon runner files next to modules.
MAX_ROWS_VISIBLE := 12                  ; Prevents an oversized popup if the folder has many scripts.

; -----------------------------
; Global state
; -----------------------------
ConfigFile := A_ScriptDir "\AHK_Hub.ini"
StartupShortcutName := "1Hub.lnk"
DefaultModuleFolder := A_ScriptDir "\modules"
ScriptFolder := LoadScriptFolder()
Modules := []                           ; Array of {Name, Path}
Pids := Map()                           ; Module full path -> PID
PopupGui := ""
PopupOpenedActiveHwnd := 0
PopupFocusReadyAt := 0
IsExitingHub := false

EnsureDir(DefaultModuleFolder)
EnsureDir(ScriptFolder)
LoadModules()
BuildTrayMenu()

; 0x404 is AutoHotkey's tray notification message.
; 0x202 = WM_LBUTTONUP. Left-click toggles the popup.
OnMessage(0x404, TrayIconEvent)
OnExit(HubOnExit)

if AUTO_START_MODULES_ON_LAUNCH
    StartAllInternal(false)

return

; =========================================================
; Settings / module discovery
; =========================================================

LoadScriptFolder() {
    global ConfigFile, DefaultModuleFolder

    try {
        folder := IniRead(ConfigFile, "Settings", "ScriptFolder", DefaultModuleFolder)
    } catch {
        folder := DefaultModuleFolder
    }

    folder := Trim(folder)
    return folder != "" ? folder : DefaultModuleFolder
}

SaveScriptFolder() {
    global ConfigFile, ScriptFolder

    try IniWrite(ScriptFolder, ConfigFile, "Settings", "ScriptFolder")
}

EnsureDir(path) {
    if !DirExist(path) {
        try DirCreate(path)
    }
}

LoadModules() {
    global Modules, ScriptFolder

    Modules := []

    if !DirExist(ScriptFolder) {
        try DirCreate(ScriptFolder)
        catch {
            return
        }
    }

    ; Top-level *.ahk files only. This intentionally avoids recursive scanning
    ; to keep startup fast and prevent accidentally running library files.
    Loop Files ScriptFolder "\*.ahk", "F" {
        fileName := A_LoopFileName
        fullPath := A_LoopFileFullPath

        ; Do not list this Hub if the selected folder is the Hub folder.
        if (fullPath = A_ScriptFullPath)
            continue

        ; Skip generated hidden runners.
        if RegExMatch(fileName, "i)^\.ahk_hub_runner__")
            continue

        ; Optional skip patterns for helper/library files.
        if (SubStr(fileName, 1, 1) = "_")
            continue
        if InStr(fileName, ".disabled.ahk")
            continue

        SplitPath(fullPath, , , , &nameNoExt)
        Modules.Push({Name: nameNoExt, Path: fullPath})
    }
}

ChooseDefaultFolder(*) {
    global ScriptFolder

    start := DirExist(ScriptFolder) ? ScriptFolder : A_ScriptDir
    selected := SelectDefaultFolder(start)

    if (selected = "")
        return

    ; Avoid orphaned scripts from the old folder.
    StopAllInternal(false)

    ScriptFolder := selected
    SaveScriptFolder()
    EnsureDir(ScriptFolder)
    LoadModules()
    RefreshHub()
}

SelectDefaultFolder(start) {
    ; Prefixing the start path with * opens a normal shell folder picker
    ; without trapping navigation inside the current folder.
    try {
        return DirSelect("*" start, 0, "Select default AHK module folder")
    } catch {
        return DirSelect(start, 0, "Select default AHK module folder")
    }
}

StartupShortcutPath() {
    global StartupShortcutName

    return A_Startup "\" StartupShortcutName
}

IsStartupRegistered() {
    shortcutPath := StartupShortcutPath()

    if !FileExist(shortcutPath)
        return false

    target := ""
    args := ""

    try {
        FileGetShortcut(shortcutPath, &target, , &args)
        return (target = A_AhkPath && InStr(args, A_ScriptFullPath)) || (target = A_ScriptFullPath)
    } catch {
        return true
    }
}

SetStartupRegistered(enabled) {
    shortcutPath := StartupShortcutPath()

    try {
        if enabled {
            if FileExist(shortcutPath)
                FileDelete(shortcutPath)

            FileCreateShortcut(
                A_AhkPath,
                shortcutPath,
                A_ScriptDir,
                QuoteShellArg(A_ScriptFullPath),
                "Start 1hub",
                A_AhkPath
            )
        } else if FileExist(shortcutPath) {
            FileDelete(shortcutPath)
        }

        return true
    } catch as err {
        action := enabled ? "register 1Hub in Windows startup" : "remove 1Hub from Windows startup"
        MsgBox("Failed to " action ":`n`n" shortcutPath "`n`n" err.Message, "1hub")
        return false
    }
}

StartupCheckboxClicked(ctrl, *) {
    desired := ctrl.Value = 1

    if !SetStartupRegistered(desired)
        ctrl.Value := IsStartupRegistered()
}

OpenScriptFolderClicked(*) {
    global ScriptFolder

    EnsureDir(ScriptFolder)

    try {
        Run("explorer.exe " QuoteShellArg(ScriptFolder))
    } catch as err {
        MsgBox("Failed to open script folder:`n" ScriptFolder "`n`n" err.Message, "1hub")
    }
}

; =========================================================
; Tray
; =========================================================

BuildTrayMenu() {
    A_IconTip := "1hub"

    A_TrayMenu.Delete()
    A_TrayMenu.Add("Open Hub", ShowHub)
    A_TrayMenu.Add()
    A_TrayMenu.Add("Start All", StartAllClicked)
    A_TrayMenu.Add("Stop All", StopAllClicked)
    A_TrayMenu.Add("Reload Running Modules", ReloadRunningModulesClicked)
    A_TrayMenu.Add()
    A_TrayMenu.Add("Exit Hub + Modules", ExitHubClicked)
}

TrayIconEvent(wParam, lParam, msg, hwnd) {
    if (lParam = 0x202) {
        ToggleHub()
        return true
    }
}

; =========================================================
; Popup UI
; =========================================================

ToggleHub(*) {
    global PopupGui

    if IsObject(PopupGui) {
        CloseHub()
        return
    }

    ShowHub()
}

ShowHub(*) {
    global PopupGui, PopupOpenedActiveHwnd, PopupFocusReadyAt

    if IsObject(PopupGui) {
        try PopupGui.Destroy()
        PopupGui := ""
        SetTimer(MonitorPopupFocus, 0)
    }

    PopupOpenedActiveHwnd := WinExist("A")
    PopupFocusReadyAt := A_TickCount + 250
    LoadModules()
    PruneDeadPids()
    BuildHubGui()
}

RefreshHub() {
    global PopupGui

    if IsObject(PopupGui)
        ShowHub()
}

CloseHub(*) {
    global PopupGui, PopupOpenedActiveHwnd, PopupFocusReadyAt

    SetTimer(MonitorPopupFocus, 0)

    if IsObject(PopupGui) {
        try PopupGui.Destroy()
    }

    PopupGui := ""
    PopupOpenedActiveHwnd := 0
    PopupFocusReadyAt := 0
}

MonitorPopupFocus(*) {
    global PopupGui, PopupOpenedActiveHwnd, PopupFocusReadyAt

    if !IsObject(PopupGui) {
        SetTimer(MonitorPopupFocus, 0)
        return
    }

    activeHwnd := WinExist("A")
    if (!activeHwnd || activeHwnd = PopupGui.Hwnd)
        return

    if (A_TickCount < PopupFocusReadyAt) {
        PopupOpenedActiveHwnd := activeHwnd
        return
    }

    if !PopupOpenedActiveHwnd {
        PopupOpenedActiveHwnd := activeHwnd
        return
    }

    if (PopupOpenedActiveHwnd && activeHwnd != PopupOpenedActiveHwnd)
        CloseHub()
}

BuildHubGui() {
    global PopupGui, ScriptFolder, Modules, MAX_ROWS_VISIBLE

    contentW := 454
    marginX := 14
    marginY := 12
    panelW := contentW + (marginX * 2)

    g := Gui("+AlwaysOnTop -Caption +ToolWindow", "1hub")
    PopupGui := g
    g.BackColor := "202020"
    g.MarginX := marginX
    g.MarginY := marginY

    ; Header
    g.SetFont("s18 Bold", "Segoe UI")
    g.AddText("xm ym w" contentW " h34 Center +0x200 cFFFFFF", "1hub")
    g.AddText("xm ym w34 h34 Center +0x200 c00CC66", "■")
    AddFlatButton(g, "x437 y18 w28 h24", "×", "neutral", CloseHub)

    g.SetFont("s9", "Segoe UI")
    g.AddText("xm y+8 w" contentW " h1 0x10")

    ; Folder section
    g.SetFont("s9 Bold", "Segoe UI")
    g.AddText("xm y+12 cD0D0D0", "Script Folder")

    g.SetFont("s9", "Segoe UI")
    g.AddEdit("xm y+5 w330 h24 ReadOnly", ScriptFolder)
    AddFlatButton(g, "x+8 yp-1 w34 h26", "📂", "neutral", ChooseDefaultFolder)
    AddFlatButton(g, "x+7 yp w34 h26", "📁", "neutral", OpenScriptFolderClicked)

    startupChecked := IsStartupRegistered() ? " Checked" : ""
    startupCb := g.AddCheckbox("xm y+7 cD0D0D0" startupChecked, "Auto Start")
    startupCb.OnEvent("Click", StartupCheckboxClicked)

    ; Modules section
    g.SetFont("s12 Bold", "Segoe UI")
    g.AddText("xm y+14 cFFFFFF", "Modules")
    g.SetFont("s8", "Segoe UI")
    g.AddText("x+12 yp+6 c888888", "Loaded from folder on launch")

    if (Modules.Length = 0) {
        g.SetFont("s10", "Segoe UI")
        g.AddText("xm y+14 cAAAAAA w" contentW, "No .ahk modules found in the selected folder.")
        g.AddText("xm y+4 c777777 w" contentW, "Use the folder button, or place scripts in the folder above.")
    } else {
        visibleRows := Min(Modules.Length, MAX_ROWS_VISIBLE)

        Loop visibleRows {
            m := Modules[A_Index]
            running := IsModuleRunning(m.Path)
            statusText := running ? "● ON" : "○ OFF"
            statusColor := running ? "44DD77" : "9A9A9A"
            actionText := running ? "■" : "▶"
            actionVariant := running ? "stopSmall" : "startSmall"

            g.SetFont("s13", "Segoe UI")
            g.AddText("xm y+9 w28 h26 cFFFFFF", GetModuleIcon(A_Index))

            g.SetFont("s10", "Segoe UI")
            g.AddText("x+8 yp+2 w220 h24 cFFFFFF", ShortenText(m.Name, 28))

            g.SetFont("s9", "Segoe UI")
            g.AddText("x+8 yp+1 w62 h24 c" statusColor, statusText)

            AddFlatButton(g, "x+12 yp-4 w34 h26", actionText, actionVariant, ToggleModuleClicked.Bind(m.Path))
            AddFlatButton(g, "x+7 yp w34 h26", "↻", "neutral", RestartModuleClicked.Bind(m.Path))
            AddFlatButton(g, "x+7 yp w34 h26", "✎", "blue", EditModuleClicked.Bind(m.Path))
        }

        if (Modules.Length > visibleRows) {
            hiddenCount := Modules.Length - visibleRows
            g.SetFont("s9", "Segoe UI")
            g.AddText("xm y+9 c888888 w" contentW, "… " hiddenCount " more scripts loaded. Use the bottom controls or reduce the folder list.")
        }
    }

    ; Bottom controls
    g.AddText("xm y+12 w" contentW " h1 0x10")
    AddFlatButton(g, "xm y+12 w44 h30", "▶▶", "green", StartAllClicked)
    AddFlatButton(g, "x+9 yp w44 h30", "■■", "red", StopAllClicked)
    AddFlatButton(g, "x+9 yp w44 h30", "↻", "blue", ReloadRunningModulesClicked)

    runningCount := CountRunningModules()
    g.SetFont("s8", "Segoe UI")
    g.AddText("xm y+10 c808080 w" contentW, "Idle • Auto-load ON • No polling • Running " runningCount "/" Modules.Length)
    panelBottomMarker := g.AddText("xm y+8 w1 h1 c202020", "")

    g.OnEvent("Escape", CloseHub)
    g.OnEvent("Close", CloseHub)

    ; Show near bottom-right. Use hidden autosize first to get exact dimensions.
    g.Show("AutoSize Hide")
    winX := 0
    winY := 0
    WinGetPos(&winX, &winY, &w, &h, "ahk_id " g.Hwnd)
    panelBottomMarker.GetPos(, &markerY, , &markerH)
    panelH := markerY + markerH + marginY
    AddPanelOutline(g, panelW, panelH)

    MonitorGetWorkArea(, &workLeft, &workTop, &workRight, &workBottom)
    x := workRight - w - 24
    y := workBottom - h - 24

    if (x < workLeft)
        x := workLeft
    if (y < workTop)
        y := workTop

    g.Show("x" x " y" y " NoActivate")
    SetTimer(MonitorPopupFocus, 120)
}

AddPanelOutline(g, w, h) {
    thickness := 5
    bottomY := h - thickness
    rightX := w - thickness

    g.AddText("x0 y0 w" w " h" thickness " BackgroundFFFFFF", "")
    g.AddText("x0 y" bottomY " w" w " h" thickness " BackgroundFFFFFF", "")
    g.AddText("x0 y0 w" thickness " h" h " BackgroundFFFFFF", "")
    g.AddText("x" rightX " y0 w" thickness " h" h " BackgroundFFFFFF", "")
}

AddFlatButton(g, options, text, variant, callback) {
    colors := FlatButtonColors(variant)

    ; Native AHK Button controls ignore most dark-mode styling and render as
    ; light system buttons. These clickable Text controls keep the existing
    ; behavior while making the buttons visually flat and dark.
    g.SetFont("s9 Bold", "Segoe UI")
    ctrl := g.AddText(
        options " Center +0x100 +0x200 +Border c" colors.Text " Background" colors.Bg,
        text
    )
    ctrl.OnEvent("Click", callback)
    return ctrl
}

FlatButtonColors(variant) {
    switch variant {
        case "green":
            return {Bg: "183323", Text: "5CE477"}
        case "red":
            return {Bg: "321F20", Text: "FF6666"}
        case "blue":
            return {Bg: "182B3D", Text: "6DBBFF"}
        case "startSmall":
            return {Bg: "1D2C22", Text: "5CE477"}
        case "stopSmall":
            return {Bg: "2B2B2B", Text: "F0F0F0"}
        case "close":
            return {Bg: "D8DCD6", Text: "202020"}
        default:
            return {Bg: "2B2B2B", Text: "F0F0F0"}
    }
}

GetModuleIcon(index) {
    icons := ["🖱", "⇧", "T", "▣", "⚙", "⌨", "▶", "◆"]
    return icons[Mod(index - 1, icons.Length) + 1]
}

ShortenText(text, maxLen) {
    return StrLen(text) > maxLen ? SubStr(text, 1, maxLen - 1) "…" : text
}

; =========================================================
; Module process control
; =========================================================

StartAllClicked(*) {
    StartAllInternal(true)
}

StopAllClicked(*) {
    StopAllInternal(true)
}

ReloadRunningModulesClicked(*) {
    ReloadRunningModulesInternal(true)
}

ToggleModuleClicked(path, *) {
    if IsModuleRunning(path)
        StopModuleInternal(path, true)
    else
        StartModuleInternal(path, true)
}

RestartModuleClicked(path, *) {
    StopModuleInternal(path, false)
    Sleep 100
    StartModuleInternal(path, false)
    RefreshHub()
}

EditModuleClicked(path, *) {
    if !FileExist(path) {
        MsgBox("Module file not found:`n" path, "1hub")
        RefreshHub()
        return
    }

    try {
        Run("*Edit " QuoteShellArg(path))
    } catch as err {
        try {
            Run(QuoteShellArg(path))
        } catch as fallbackErr {
            MsgBox("Failed to open module editor:`n" path "`n`n" fallbackErr.Message, "1hub")
        }
    }
}

StartAllInternal(refresh := true) {
    global Modules

    LoadModules()

    for _, m in Modules
        StartModuleInternal(m.Path, false)

    if refresh
        RefreshHub()
}

StopAllInternal(refresh := true) {
    global Pids

    paths := []
    for path, pid in Pids
        paths.Push(path)

    for _, path in paths
        StopModuleInternal(path, false)

    if refresh
        RefreshHub()
}

ReloadRunningModulesInternal(refresh := true) {
    global Modules

    runningPaths := []

    for _, m in Modules {
        if IsModuleRunning(m.Path)
            runningPaths.Push(m.Path)
    }

    ; Rescan folder first so deleted/renamed modules are not restarted.
    LoadModules()

    for _, path in runningPaths {
        if FileExist(path) {
            StopModuleInternal(path, false)
            Sleep 80
            StartModuleInternal(path, false)
        }
    }

    if refresh
        RefreshHub()
}

StartModuleInternal(path, refresh := true) {
    global Pids, USE_HIDDEN_RUNNERS

    if IsModuleRunning(path) {
        if refresh
            RefreshHub()
        return
    }

    if !FileExist(path) {
        MsgBox("Module file not found:`n" path, "1hub")
        if refresh
            RefreshHub()
        return
    }

    SplitPath(path, , &moduleDir)
    runnerPath := path

    if USE_HIDDEN_RUNNERS {
        try {
            runnerPath := EnsureHiddenRunner(path)
        } catch as err {
            ; Fallback: launch directly. It may show its own tray icon unless the module has #NoTrayIcon.
            runnerPath := path
            MsgBox("Hidden runner could not be created. Launching directly:`n`n" path "`n`n" err.Message, "1hub")
        }
    }

    q := Chr(34)
    commandLine := q A_AhkPath q " " q runnerPath q

    try {
        Run(commandLine, moduleDir, "", &pid)
        Pids[path] := pid
    } catch as err {
        MsgBox("Failed to start module:`n" path "`n`n" err.Message, "1hub")
    }

    if refresh
        RefreshHub()
}

StopModuleInternal(path, refresh := true) {
    global Pids

    if !IsModuleRunning(path) {
        if refresh
            RefreshHub()
        return
    }

    pid := Pids[path]

    ; Ask the hidden AutoHotkey main window to close first.
    try WinClose("ahk_pid " pid)
    Sleep 300

    ; If it did not exit, force-close the process.
    if ProcessExist(pid) {
        try ProcessClose(pid)
    }

    if Pids.Has(path)
        Pids.Delete(path)

    if refresh
        RefreshHub()
}

IsModuleRunning(path) {
    global Pids

    if !Pids.Has(path)
        return false

    pid := Pids[path]

    if ProcessExist(pid)
        return true

    Pids.Delete(path)
    return false
}

PruneDeadPids() {
    global Pids

    dead := []
    for path, pid in Pids {
        if !ProcessExist(pid)
            dead.Push(path)
    }

    for _, path in dead
        Pids.Delete(path)
}

CountRunningModules() {
    global Modules

    count := 0
    for _, m in Modules {
        if IsModuleRunning(m.Path)
            count += 1
    }
    return count
}

; =========================================================
; Hidden runner generation
; =========================================================

EnsureHiddenRunner(modulePath) {
    runnerPath := GetRunnerPath(modulePath)
    SplitPath(modulePath, , &moduleDir)

    content := "#Requires AutoHotkey v2.0`n"
        . "#SingleInstance Force`n"
        . "#NoTrayIcon`n"
        . "; Generated by AHK Hub. Do not edit.`n"
        . "SetWorkingDir(" QuoteAhkString(moduleDir) ")`n"
        . "#Include " QuoteAhkString(modulePath) "`n"

    existing := ""
    try existing := FileRead(runnerPath, "UTF-8")

    if (existing != content) {
        if FileExist(runnerPath) {
            try FileSetAttrib("-H", runnerPath)
            try FileDelete(runnerPath)
        }
        FileAppend(content, runnerPath, "UTF-8")
        try FileSetAttrib("+H", runnerPath)
    }

    return runnerPath
}

GetRunnerPath(modulePath) {
    SplitPath(modulePath, , &moduleDir, , &nameNoExt)
    safeName := RegExReplace(nameNoExt, "[^\w가-힣.-]", "_")

    if (safeName = "")
        safeName := "module"

    return moduleDir "\.ahk_hub_runner__" safeName "__" SimpleHash(modulePath) ".ahk"
}

SimpleHash(text) {
    hash := 2166136261

    Loop Parse text {
        hash := Mod((hash ^ Ord(A_LoopField)) * 16777619, 4294967296)
    }

    return Format("{:08X}", hash)
}

QuoteAhkString(text) {
    quote := Chr(34)
    tick := Chr(96)

    text := StrReplace(text, tick, tick tick)
    text := StrReplace(text, quote, quote quote)

    return quote text quote
}

QuoteShellArg(text) {
    quote := Chr(34)
    return quote StrReplace(text, quote, quote quote) quote
}

; =========================================================
; Exit / emergency hotkeys
; =========================================================

ExitHubClicked(*) {
    global IsExitingHub

    IsExitingHub := true
    StopAllInternal(false)
    ExitApp()
}

HubOnExit(exitReason, exitCode) {
    global IsExitingHub

    ; Prevent child modules from remaining after normal hub exit/reload.
    if !IsExitingHub
        StopAllInternal(false)
}

^!+r::Reload()          ; Ctrl + Alt + Shift + R = reload Hub.
^!+q::ExitHubClicked() ; Ctrl + Alt + Shift + Q = exit Hub + modules.

@echo off
setlocal EnableDelayedExpansion
chcp 936 >nul
title CMP 30HX Gen2 解锁工具 v2.0 (改进中文版)

:: ================================================================
:: 改进要点：
::  1. 修改系统设置前自动备份原值，卸载时完整恢复
::  2. 只创建一个"登录时"触发器，避免双窗口/双 UAC
::  3. Run 键仅在任务创建失败时写入
::  4. Soft Reset 前二次确认，避免无谓链路降宽
::  5. 全程日志记录到 %ProgramData%\40HXUnlock\setup.log
::  6. 不依赖外部 PowerShell 脚本
:: ================================================================

:: ---------- 路径与全局变量 ----------
set "BASE_DIR=%ProgramFiles%\40HXUnlock"
set "DATA_DIR=%ProgramData%\40HXUnlock"
set "BACKUP_DIR=%DATA_DIR%\backup"
set "BACKUP_FILE=%BACKUP_DIR%\settings.ini"
set "LOG_FILE=%DATA_DIR%\setup.log"
set "STATUS_FILE=%DATA_DIR%\gen2_status.txt"
set "TASK_NAME=CMP30HX_Gen2_Unlock"
set "RUN_KEY_NAME=CMP30HX_Gen2"

:: ---------- 参数默认值 ----------
set "IS_ADMIN=0"
set "DO_INSTALL=0"
set "DO_UNINSTALL=0"
set "DO_FIX_NVCPL=0"
set "NO_TASK=0"
set "NO_WAIT=0"
set "NO_CHECK=0"
set "FORCE_RESET=0"

for %%a in (%*) do (
    if /i "%%~a"=="-noadmin"   set "IS_ADMIN=1"
    if /i "%%~a"=="/noadmin"   set "IS_ADMIN=1"
    if /i "%%~a"=="-install"   set "DO_INSTALL=1"
    if /i "%%~a"=="/install"   set "DO_INSTALL=1"
    if /i "%%~a"=="-uninstall" set "DO_UNINSTALL=1"
    if /i "%%~a"=="/uninstall" set "DO_UNINSTALL=1"
    if /i "%%~a"=="-u"         set "DO_UNINSTALL=1"
    if /i "%%~a"=="/u"         set "DO_UNINSTALL=1"
    if /i "%%~a"=="-fix-nvcpl" set "DO_FIX_NVCPL=1"
    if /i "%%~a"=="/fix-nvcpl" set "DO_FIX_NVCPL=1"
    if /i "%%~a"=="-notask"    set "NO_TASK=1"
    if /i "%%~a"=="/notask"    set "NO_TASK=1"
    if /i "%%~a"=="-nowait"    set "NO_WAIT=1"
    if /i "%%~a"=="/nowait"    set "NO_WAIT=1"
    if /i "%%~a"=="-nocheck"   set "NO_CHECK=1"
    if /i "%%~a"=="/nocheck"   set "NO_CHECK=1"
    if /i "%%~a"=="-force-reset" set "FORCE_RESET=1"
    if /i "%%~a"=="/force-reset" set "FORCE_RESET=1"
)

:: ---------- UAC 提权 ----------
if "%IS_ADMIN%"=="0" (
    fltmc >nul 2>&1 && set "IS_ADMIN=1"
)
if "%IS_ADMIN%"=="0" (
    echo [*] 正在请求管理员权限...
    set "CURRENT_SCRIPT=%~f0"
    set "CURRENT_DIR=%~dp0"
    set "SCRIPT_ARGS=%*"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=$env:CURRENT_SCRIPT; $d=$env:CURRENT_DIR; $a=$env:SCRIPT_ARGS; $q=[char]34; $p = if ($a) { '/c ' + $q + $s + $q + ' ' + $a } else { '/c ' + $q + $s + $q }; Start-Process -FilePath $env:ComSpec -ArgumentList $p -WorkingDirectory $d -Verb RunAs" >nul 2>&1
    if errorlevel 1 (
        echo [X] 无法自动请求管理员权限。
        echo     请右键本文件，选择"以管理员身份运行"。
        pause
    )
    exit /b
)

cd /d "%~dp0"
if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" >nul 2>&1
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%" >nul 2>&1

:: ---------- 参数分发 ----------
if "%DO_UNINSTALL%"=="1" goto :uninstall
if "%DO_FIX_NVCPL%"=="1" goto :fix_nvcpl
if "%DO_INSTALL%"=="1"   goto :install
goto :menu


:: ================================================================
:: 交互菜单
:: ================================================================
:menu
cls
echo ================================================================
echo    CMP 30HX Gen2 x16 解锁工具 [改进中文版 v2.0]
echo ================================================================
echo.
echo   [1] 安装并解锁 Gen2 x16（推荐）
echo       - 备份当前系统设置，可完整还原
echo       - 部署 installer，创建单一登录任务
echo       - 解锁 PCIe Gen2 x16（5.0 GT/s）
echo       - 清理 WinRing0/ThrottleStop，兼容反作弊
echo.
echo   [2] 卸载并恢复系统设置
echo       - 删除任务、Run 键、驱动
echo       - 从备份还原 ASPM / HVCI / Blocklist / Fast Startup
echo       - 删除安装目录
echo.
echo   [3] 仅修复 NVIDIA 控制面板
echo.
echo   [4] 仅解 Gen2（不改任何系统设置，适合已装好的用户）
echo.
echo   [5] 退出
echo.
echo ================================================================
choice /c 12345 /t 10 /d 5 /m "请选择 [1-5]，10 秒后默认退出："
if errorlevel 5 exit /b 0
if errorlevel 4 goto :quick_unlock
if errorlevel 3 goto :fix_nvcpl
if errorlevel 2 goto :uninstall
if errorlevel 1 goto :install
goto :menu


:: ================================================================
:: 快速解锁：只跑 installer，不改系统设置
:: ================================================================
:quick_unlock
call :init_log
echo.
echo [*] 仅解锁 Gen2，不修改任何系统设置...
call :find_installer
if not defined INSTALLER_PATH (
    echo [X] 未找到 40HXInstaller.exe，请把本脚本放在原包同一目录下。
    pause
    exit /b 1
)
echo [*] 调用: "%INSTALLER_PATH%" -gen2-30hx -silent
"%INSTALLER_PATH%" -gen2-30hx -silent
call :log "installer 返回: %ERRORLEVEL%"
echo.
echo [V] 完成。请用 GPU-Z 点击 Bus Interface 旁的 [?] 跑 Render Test 验证。
pause
exit /b 0


:: ================================================================
:: 安装主流程
:: ================================================================
:install
cls
echo ================================================================
echo    安装并解锁 Gen2 x16
echo ================================================================
echo.
call :init_log
call :log "===== 开始安装 ====="

call :find_installer
if not defined INSTALLER_PATH (
    echo [X] 未找到 40HXInstaller.exe！
    echo     请把本脚本放在原包 windows-v3.0\release\ 或 release\ 目录下。
    pause
    exit /b 1
)

call :backup_settings
call :deploy_files
call :apply_system_tweaks
call :create_task
call :unlock_gen2
call :cleanup_byovd
call :summary

if not "%NO_WAIT%"=="1" pause
exit /b 0


:: ================================================================
:: 查找 installer
:: ================================================================
:find_installer
set "INSTALLER_PATH="
if exist "%~dp0windows-v3.0\release\40HXInstaller.exe" set "INSTALLER_PATH=%~dp0windows-v3.0\release\40HXInstaller.exe"
if not defined INSTALLER_PATH if exist "%~dp0release\40HXInstaller.exe" set "INSTALLER_PATH=%~dp0release\40HXInstaller.exe"
if not defined INSTALLER_PATH if exist "%~dp040HXInstaller.exe" set "INSTALLER_PATH=%~dp040HXInstaller.exe"
if not defined INSTALLER_PATH if exist "%BASE_DIR%\40HXInstaller.exe" set "INSTALLER_PATH=%BASE_DIR%\40HXInstaller.exe"
exit /b 0


:: ================================================================
:: 备份系统设置
:: ================================================================
:backup_settings
if exist "%BACKUP_FILE%" (
    echo [*] 已有备份文件，跳过备份：%BACKUP_FILE%
    call :log "备份已存在，跳过"
    exit /b 0
)
echo [*] 备份当前系统设置到 %BACKUP_FILE%
> "%BACKUP_FILE%" echo ; CMP 30HX 系统设置备份
>>"%BACKUP_FILE%" echo ; 备份时间: %date% %time%

:: HiberbootEnabled
set "v="
for /f "tokens=2,3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v "HiberbootEnabled" 2^>nul ^| findstr /i "HiberbootEnabled"') do set "v=%%b"
if defined v >>"%BACKUP_FILE%" echo HiberbootEnabled=%v%

:: VulnerableDriverBlocklistEnable
set "v="
for /f "tokens=2,3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\CI\Config" /v "VulnerableDriverBlocklistEnable" 2^>nul ^| findstr /i "VulnerableDriverBlocklistEnable"') do set "v=%%b"
if defined v >>"%BACKUP_FILE%" echo VulnerableDriverBlocklistEnable=%v%

:: HVCI
set "v="
for /f "tokens=2,3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "Enabled" 2^>nul ^| findstr /i "Enabled"') do set "v=%%b"
if defined v >>"%BACKUP_FILE%" echo HVCI_Enabled=%v%

:: ASPM（AC / DC）
set "aspm_ac="
set "aspm_dc="
for /f "tokens=2 delims=:" %%a in ('powercfg /query SCHEME_CURRENT SUB_PCIEXPRESS ee12f906-d277-404b-b6da-e5fa1a576df5 2^>nul ^| findstr /i "交流"') do (
    set "aspm_ac=%%a"
    set "aspm_ac=!aspm_ac: =!"
)
for /f "tokens=2 delims=:" %%a in ('powercfg /query SCHEME_CURRENT SUB_PCIEXPRESS ee12f906-d277-404b-b6da-e5fa1a576df5 2^>nul ^| findstr /i "直流"') do (
    set "aspm_dc=%%a"
    set "aspm_dc=!aspm_dc: =!"
)
if defined aspm_ac >>"%BACKUP_FILE%" echo ASPM_AC=!aspm_ac!
if defined aspm_dc >>"%BACKUP_FILE%" echo ASPM_DC=!aspm_dc!

echo       [OK] 备份完成
call :log "备份完成"
exit /b 0


:: ================================================================
:: 部署文件
:: ================================================================
:deploy_files
echo [*] 部署 installer 到 %BASE_DIR%
if not exist "%BASE_DIR%" mkdir "%BASE_DIR%" >nul 2>&1
copy /y "%INSTALLER_PATH%" "%BASE_DIR%\40HXInstaller.exe" >nul 2>&1
if exist "%~dp0windows-v3.0\release\40HXCheck.exe" copy /y "%~dp0windows-v3.0\release\40HXCheck.exe" "%BASE_DIR%\40HXCheck.exe" >nul 2>&1
if exist "%~dp0release\40HXCheck.exe"            copy /y "%~dp0release\40HXCheck.exe" "%BASE_DIR%\40HXCheck.exe" >nul 2>&1
set "INSTALLER_PATH=%BASE_DIR%\40HXInstaller.exe"

:: 写入 RunUnlock.bat（脚本内联生成，不依赖外部文件）
set "RUNNER=%BASE_DIR%\RunUnlock.bat"
> "%RUNNER%" echo @echo off
>>"%RUNNER%" echo setlocal
>>"%RUNNER%" echo cd /d "%BASE_DIR%"
>>"%RUNNER%" echo where nvidia-smi ^>nul 2^>^&1 ^&^& nvidia-smi -pm 1 ^>nul 2^>^&1
>>"%RUNNER%" echo "40HXInstaller.exe" -gen2-30hx -silent
>>"%RUNNER%" echo where nvidia-smi ^>nul 2^>^&1 ^&^& nvidia-smi -pm 1 ^>nul 2^>^&1
>>"%RUNNER%" echo sc stop WinRing0_1_2_0 ^>nul 2^>^&1
>>"%RUNNER%" echo sc delete WinRing0_1_2_0 ^>nul 2^>^&1
>>"%RUNNER%" echo sc stop ThrottleStop ^>nul 2^>^&1
>>"%RUNNER%" echo sc delete ThrottleStop ^>nul 2^>^&1
>>"%RUNNER%" echo del /f /q "%%SystemRoot%%\System32\drivers\WinRing0x64.sys" ^>nul 2^>^&1
>>"%RUNNER%" echo del /f /q "%%SystemRoot%%\System32\drivers\ThrottleStop.sys" ^>nul 2^>^&1
>>"%RUNNER%" echo sc config NVDisplay.ContainerLocalSystem start= auto ^>nul 2^>^&1
>>"%RUNNER%" echo sc start NVDisplay.ContainerLocalSystem ^>nul 2^>^&1
>>"%RUNNER%" echo reg add "HKCR\Directory\Background\shellex\ContextMenuHandlers\NvCplDesktopContext" /ve /t REG_SZ /d "{3D1975AF-48C6-4f8e-A182-BE0E08FA86A9}" /f ^>nul 2^>^&1
>>"%RUNNER%" echo endlocal
echo       [OK] 部署完成
call :log "部署完成: %BASE_DIR%"
exit /b 0


:: ================================================================
:: 修改系统设置（ASPM / HVCI / Blocklist / Fast Startup）
:: ================================================================
:apply_system_tweaks
echo [*] 修改系统设置（原值已备份，可通过菜单 [2] 完整恢复）

:: 关闭休眠 / 快速启动
powercfg -h off >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v "HiberbootEnabled" /t REG_DWORD /d 0 /f >nul 2>&1

:: 关闭 ASPM
powercfg /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ee12f906-d277-404b-b6da-e5fa1a576df5 0 >nul 2>&1
powercfg /setdcvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ee12f906-d277-404b-b6da-e5fa1a576df5 0 >nul 2>&1
powercfg /setactive SCHEME_CURRENT >nul 2>&1

:: 关闭 Vulnerable Driver Blocklist
reg add "HKLM\SYSTEM\CurrentControlSet\Control\CI\Config" /v "VulnerableDriverBlocklistEnable" /t REG_DWORD /d 0 /f >nul 2>&1

:: 关闭 HVCI
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "Enabled" /t REG_DWORD /d 0 /f >nul 2>&1

:: Test Signing 若开启则关闭
bcdedit 2>nul | findstr /i "testsigning" | findstr /i "yes" >nul 2>&1
if not errorlevel 1 (
    bcdedit /set testsigning off >nul 2>&1
    call :log "Test Signing 已关闭"
)

:: 恢复 NVDisplay 服务
sc config NVDisplay.ContainerLocalSystem start= auto >nul 2>&1
sc start NVDisplay.ContainerLocalSystem >nul 2>&1
where nvidia-smi >nul 2>&1 && nvidia-smi -pm 1 >nul 2>&1

echo       [OK] 系统设置已调整
call :log "系统设置已调整"
exit /b 0


:: ================================================================
:: 创建计划任务（单一登录触发器，单行 schtasks）
:: ================================================================
:create_task
if "%NO_TASK%"=="1" (
    echo [*] 已指定 -notask，跳过创建任务
    set "TASK_OK=1"
    exit /b 0
)
echo [*] 创建登录计划任务 %TASK_NAME%
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1

schtasks /create /tn "%TASK_NAME%" /tr "\"%BASE_DIR%\RunUnlock.bat\"" /sc onlogon /delay 0000:30 /rl highest /ru "NT AUTHORITY\SYSTEM" /f >nul 2>&1

schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if errorlevel 1 (
    echo       [!] 任务创建失败，回退到 Run 键
    set "TASK_OK=0"
    reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v "%RUN_KEY_NAME%" /t REG_SZ /d "\"%BASE_DIR%\RunUnlock.bat\"" /f >nul 2>&1
) else (
    echo       [OK] 任务已创建（登录后 30 秒触发，SYSTEM 权限，无 UAC）
    set "TASK_OK=1"
)
call :log "任务创建: TASK_OK=%TASK_OK%"
exit /b 0


:: ================================================================
:: Gen2 解锁
:: ================================================================
:unlock_gen2
echo.
echo [*] 调用 installer 解锁 Gen2...
if exist "%STATUS_FILE%" del /f /q "%STATUS_FILE%" >nul 2>&1

"%INSTALLER_PATH%" -gen2-30hx -silent
set "RC=%ERRORLEVEL%"
call :log "installer 返回: %RC%"

if not exist "%STATUS_FILE%" (
    echo       [X] 未生成状态文件，installer 可能被拦或崩溃
    echo          请检查杀毒软件是否拦截 %BASE_DIR%\40HXInstaller.exe
    set "UNLOCK_OK=0"
    exit /b 0
)

echo       [*] installer 状态文件内容:
echo       ------------------------------------------------
type "%STATUS_FILE%"
echo       ------------------------------------------------
call :log "状态文件内容已写入日志"

findstr /i /c:"STATUS_CODE=GEN2_SUCCESS" "%STATUS_FILE%" >nul 2>&1
if not errorlevel 1 (
    echo       [V] Gen2 解锁成功
    set "UNLOCK_OK=1"
    exit /b 0
)

findstr /i /c:"STATUS_CODE=DRV_FAIL" "%STATUS_FILE%" >nul 2>&1
if not errorlevel 1 (
    echo       [X] 驱动被拦（HVCI/Blocklist/杀软），需重启后再试
    set "NEED_REBOOT=1"
    set "UNLOCK_OK=0"
    exit /b 0
)

findstr /i /c:"STATUS_CODE=NO_GPU" "%STATUS_FILE%" >nul 2>&1
if not errorlevel 1 (
    echo       [X] 未找到 GPU，请检查供电/插槽/BIOS
    set "UNLOCK_OK=0"
    exit /b 0
)

findstr /i /c:"STATUS_CODE=GEN1_STUCK" "%STATUS_FILE%" >nul 2>&1
if not errorlevel 1 (
    echo       [!] 检测到 GPU 仍停在 Gen1
    if "%FORCE_RESET%"=="1" (
        echo       [*] -force-reset 已指定，执行软复位...
        call :soft_reset
        "%INSTALLER_PATH%" -gen2-30hx -silent
        call :log "复位后 installer 返回: %ERRORLEVEL%"
        findstr /i /c:"STATUS_CODE=GEN2_SUCCESS" "%STATUS_FILE%" >nul 2>&1
        if not errorlevel 1 (
            echo       [V] 软复位后 Gen2 成功
            set "UNLOCK_OK=1"
        ) else (
            echo       [X] 软复位后仍未成功
            set "UNLOCK_OK=0"
        )
    ) else (
        echo       [提示] 默认不自动软复位，以免链路降宽。
        echo              GPU-Z 点击 Bus Interface 旁 [?] 跑 Render Test 后：
        echo              - 若变 Gen2 x16：成功（空闲时 Gen1 是正常省电）
        echo              - 若仍 Gen1：可用 -force-reset 参数重试
        echo              - 若变 Gen2 x4 / Gen1 x4：清 CMOS 重置 BIOS 后再解
        set "UNLOCK_OK=0"
    )
    exit /b 0
)

echo       [X] 未知状态，请把状态文件内容发给开发者
set "UNLOCK_OK=0"
exit /b 0


:: ================================================================
:: 软复位（仅 -force-reset 时调用）
:: ================================================================
:soft_reset
echo [*] 软复位 NVDisplay 服务...
sc stop NVDisplay.ContainerLocalSystem >nul 2>&1
timeout /t 2 /nobreak >nul
sc start NVDisplay.ContainerLocalSystem >nul 2>&1
reg add "HKCR\Directory\Background\shellex\ContextMenuHandlers\NvCplDesktopContext" /ve /t REG_SZ /d "{3D1975AF-48C6-4f8e-A182-BE0E08FA86A9}" /f >nul 2>&1
exit /b 0


:: ================================================================
:: 清理 BYOVD 驱动
:: ================================================================
:cleanup_byovd
sc stop WinRing0_1_2_0 >nul 2>&1
sc delete WinRing0_1_2_0 >nul 2>&1
sc stop ThrottleStop >nul 2>&1
sc delete ThrottleStop >nul 2>&1
del /f /q "%SystemRoot%\System32\drivers\WinRing0x64.sys" >nul 2>&1
del /f /q "%SystemRoot%\System32\drivers\ThrottleStop.sys" >nul 2>&1
sc config NVDisplay.ContainerLocalSystem start= auto >nul 2>&1
sc start NVDisplay.ContainerLocalSystem >nul 2>&1
exit /b 0


:: ================================================================
:: 汇总
:: ================================================================
:summary
echo.
echo ================================================================
if "%UNLOCK_OK%"=="1" (
    echo  [V] 安装完成 - Gen2 已解锁
) else (
    echo  [!] 安装未完全成功，请根据上面的提示处理
)
echo ================================================================
echo  - 计划任务: %TASK_NAME%（登录后 30 秒，SYSTEM 权限）
if "%TASK_OK%"=="0" echo  - Run 键: %RUN_KEY_NAME%（任务失败，已回退）
echo  - 日志文件: %LOG_FILE%
echo  - 备份文件: %BACKUP_FILE%
echo.
echo  [重要] 若要完全还原系统设置，请运行: %~nx0 -uninstall
echo.
if "%NEED_REBOOT%"=="1" (
    echo  [!] 需要重启才能让 HVCI/Blocklist 关闭生效
    echo      重启后任务会自动重试解锁
)
echo ================================================================
call :log "===== 安装结束 UNLOCK_OK=%UNLOCK_OK% ====="
exit /b 0


:: ================================================================
:: 卸载并恢复系统设置
:: ================================================================
:uninstall
cls
echo ================================================================
echo    卸载并恢复系统设置
echo ================================================================
echo.
call :init_log
call :log "===== 开始卸载 ====="

echo [*] 删除计划任务...
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
schtasks /delete /tn "%TASK_NAME%_User" /f >nul 2>&1
schtasks /delete /tn "40HXGen2Retry" /f >nul 2>&1
schtasks /delete /tn "40HX PCIe Gen2 Bring-up" /f >nul 2>&1
echo       [OK]

echo [*] 删除 Run 键...
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v "%RUN_KEY_NAME%" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "40HXGen2" /f >nul 2>&1
echo       [OK]

call :restore_settings

echo [*] 清理 BYOVD 驱动...
call :cleanup_byovd
echo       [OK]

echo [*] 删除安装目录与状态文件...
if exist "%STATUS_FILE%" del /f /q "%STATUS_FILE%" >nul 2>&1
if exist "%BASE_DIR%" rmdir /s /q "%BASE_DIR%" >nul 2>&1
echo       [OK]

echo.
echo ================================================================
echo  [V] 卸载完成，系统设置已还原
echo ================================================================
echo  - 备份文件保留在: %BACKUP_FILE%
echo  - 日志文件保留在: %LOG_FILE%
echo  - 如需彻底清理，可手动删除: %DATA_DIR%
echo ================================================================
call :log "===== 卸载结束 ====="
if not "%NO_WAIT%"=="1" pause
exit /b 0


:: ================================================================
:: 从备份恢复系统设置
:: ================================================================
:restore_settings
if not exist "%BACKUP_FILE%" (
    echo [!] 未找到备份文件 %BACKUP_FILE%，跳过恢复
    echo     如需手动恢复，请参考 README 或重装系统
    exit /b 0
)
echo [*] 从 %BACKUP_FILE% 恢复系统设置...

for /f "usebackq tokens=1,* delims==" %%k in ("%BACKUP_FILE%") do (
    set "key=%%k"
    set "val=%%l"
    if not "!key:~0,1!"==";" (
        if /i "!key!"=="HiberbootEnabled" (
            if "!val!"=="0x1" reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v "HiberbootEnabled" /t REG_DWORD /d 1 /f >nul 2>&1
            if "!val!"=="0x0" reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v "HiberbootEnabled" /t REG_DWORD /d 0 /f >nul 2>&1
        )
        if /i "!key!"=="VulnerableDriverBlocklistEnable" (
            if "!val!"=="0x1" reg add "HKLM\SYSTEM\CurrentControlSet\Control\CI\Config" /v "VulnerableDriverBlocklistEnable" /t REG_DWORD /d 1 /f >nul 2>&1
            if "!val!"=="0x0" reg add "HKLM\SYSTEM\CurrentControlSet\Control\CI\Config" /v "VulnerableDriverBlocklistEnable" /t REG_DWORD /d 0 /f >nul 2>&1
        )
        if /i "!key!"=="HVCI_Enabled" (
            if "!val!"=="0x1" reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "Enabled" /t REG_DWORD /d 1 /f >nul 2>&1
            if "!val!"=="0x0" reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "Enabled" /t REG_DWORD /d 0 /f >nul 2>&1
        )
        if /i "!key!"=="ASPM_AC" (
            powercfg /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ee12f906-d277-404b-b6da-e5fa1a576df5 !val! >nul 2>&1
        )
        if /i "!key!"=="ASPM_DC" (
            powercfg /setdcvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ee12f906-d277-404b-b6da-e5fa1a576df5 !val! >nul 2>&1
        )
    )
)
powercfg /setactive SCHEME_CURRENT >nul 2>&1

findstr /i "HiberbootEnabled=0x1" "%BACKUP_FILE%" >nul 2>&1
if not errorlevel 1 powercfg -h on >nul 2>&1

reg delete "HKLM\SOFTWARE\40HXUnlock" /f >nul 2>&1

echo       [OK] 系统设置已恢复
call :log "系统设置已恢复"
exit /b 0


:: ================================================================
:: NVIDIA 控制面板修复
:: ================================================================
:fix_nvcpl
cls
echo ================================================================
echo    修复 NVIDIA 控制面板
echo ================================================================
echo.
call :init_log
sc config NVDisplay.ContainerLocalSystem start= auto >nul 2>&1
net stop NVDisplay.ContainerLocalSystem >nul 2>&1
net start NVDisplay.ContainerLocalSystem >nul 2>&1
reg add "HKCR\Directory\Background\shellex\ContextMenuHandlers\NvCplDesktopContext" /ve /t REG_SZ /d "{3D1975AF-48C6-4f8e-A182-BE0E08FA86A9}" /f >nul 2>&1
echo       [OK] 已完成。右键桌面可验证。
call :log "NVCpl 修复完成"
if not "%NO_WAIT%"=="1" pause
exit /b 0


:: ================================================================
:: 初始化日志
:: ================================================================
:init_log
if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" >nul 2>&1
>>"%LOG_FILE%" echo.
>>"%LOG_FILE%" echo ================================================================
>>"%LOG_FILE%" echo [%date% %time%] 脚本启动 v2.0
>>"%LOG_FILE%" echo ================================================================
exit /b 0

:log
>>"%LOG_FILE%" echo [%date% %time%] %~1
exit /b 0
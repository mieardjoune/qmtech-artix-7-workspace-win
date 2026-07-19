::  Copyright 2026 M. I. E. ARDJOUNE
::
::  Licensed under the Apache License, Version 2.0 (the "License");
::  you may not use this file except in compliance with the License.
::  You may obtain a copy of the License at
::
::      http://www.apache.org/licenses/LICENSE-2.0
::
::  Unless required by applicable law or agreed to in writing, software
::  distributed under the License is distributed on an "AS IS" BASIS,
::  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
::  See the License for the specific language governing permissions and
::  limitations under the License.
::
@echo off
setlocal enabledelayedexpansion

REM Usage: ./make.cmd ^<target^> ^<project^>
REM Targets: sim, sim-vhdl, sim-sv, build, sim-gate, deploy, all, clean, tidy

set VIVADO_PATH=C:\Xilinx\Vivado
set VIVADO_VER=2022.1
set VIVADO_BASE=%VIVADO_PATH%\%VIVADO_VER%

REM cmd.exe splits on "=" the same as on space when populating %1 %2 %3,
REM so "./make.cmd sim PRJ=ram_test" arrives as three args (sim / PRJ / ram_test),
REM not two. Handle that split explicitly rather than scanning %* for "PRJ=".
set TARGET=%1
set ARG2=%2
set ARG3=%3
set PRJ=

if /i "%ARG2%"=="PRJ" (
    set PRJ=%ARG3%
) else if "%ARG2:~0,4%"=="PRJ=" (
    set PRJ=%ARG2:~4%
) else (
    set PRJ=%ARG2%
)

if "%TARGET%"=="" (
    echo Usage: ./make.cmd ^<target^> ^<project^>
    echo Targets: sim, sim-vhdl, sim-sv, build, sim-gate, deploy, all, clean, tidy
    exit /b 1
)

set PRJ_DIR=projects\%PRJ%
set TOP=
if exist "%PRJ_DIR%\TOP" set /p TOP=<"%PRJ_DIR%\TOP"

if /i "%TARGET%"=="sim"      ( call :check_env&&call :sim&&exit /b 0 || exit /b 1 )
if /i "%TARGET%"=="sim-vhdl" ( call :check_env&&call :sim_vhdl&&exit /b 0 || exit /b 1 )
if /i "%TARGET%"=="sim-sv"   ( call :check_env&&call :sim_sv&&exit /b 0 || exit /b 1 )
if /i "%TARGET%"=="build"    ( call :check_env&&call :ensure_vivado&&call :build&&exit /b 0 || exit /b 1 )
if /i "%TARGET%"=="sim-gate" ( call :check_env&&call :ensure_vivado&&call :sim_gate&&exit /b 0 || exit /b 1 )
if /i "%TARGET%"=="deploy"   ( call :check_env&&call :ensure_vivado&&call :deploy&&exit /b 0 || exit /b 1 )
if /i "%TARGET%"=="all"      ( call :all&&exit /b 0 || exit /b 1 )
if /i "%TARGET%"=="clean"    ( call :check_env&&call :clean&&exit /b 0 || exit /b 1 )
if /i "%TARGET%"=="tidy"     ( call :tidy&&exit /b 0 || exit /b 1 )

echo [ERROR] Unknown target: %TARGET%
exit /b 1

:ensure_vivado
where vivado >nul 2>&1
if not errorlevel 1 exit /b 0
if exist "%VIVADO_BASE%\settings64.bat" (
    call "%VIVADO_BASE%\settings64.bat" >nul
)
where vivado >nul 2>&1
if errorlevel 1 (
    echo [ERROR] 'vivado' not found on PATH, and %VIVADO_BASE%\settings64.bat was not found.
    echo [HINT] Set VIVADO_PATH/VIVADO_VER at the top of this script to match your install.
    exit /b 1
)
exit /b 0

:check_env
if "%PRJ%"=="" (
    echo [ERROR] Project not set. Usage: ./make.cmd ^<target^> ^<project^>
    exit /b 1
)
if not exist "%PRJ_DIR%" (
    echo [ERROR] Project directory %PRJ_DIR% does not exist.
    exit /b 1
)
if "%TOP%"=="" (
    echo [ERROR] Missing TOP file in %PRJ_DIR%.
    exit /b 1
)
exit /b 0

:sim
set HAS_VHDL=0
set HAS_SV=0
if exist "%PRJ_DIR%\src\*.vhd"  set HAS_VHDL=1
if exist "%PRJ_DIR%\src\*.vhdl" set HAS_VHDL=1
if exist "%PRJ_DIR%\src\*.sv"   set HAS_SV=1
if exist "%PRJ_DIR%\src\*.v"    set HAS_SV=1

if "%HAS_VHDL%"=="1" if "%HAS_SV%"=="1" (
    echo [ERROR] Mixed VHDL and SystemVerilog in %PRJ_DIR%\src -- isolate RTL to one language.
    exit /b 1
)
if "%HAS_VHDL%"=="1" ( call :sim_vhdl & exit /b !errorlevel! )
if "%HAS_SV%"=="1"   ( call :sim_sv   & exit /b !errorlevel! )
echo [ERROR] No HDL sources found in %PRJ_DIR%\src.
exit /b 1

:sim_vhdl
echo [SIM:VHDL] GHDL, IEEE 1076-2008
if not exist "%PRJ_DIR%\sim" mkdir "%PRJ_DIR%\sim"
pushd "%PRJ_DIR%\sim"
ghdl -a --std=08 ..\src\*.vhd ..\tb\*.vhd
if errorlevel 1 ( echo [ERROR] GHDL analysis failed. & popd & exit /b 1 )
ghdl -e --std=08 %TOP%_tb
if errorlevel 1 ( echo [ERROR] GHDL elaboration failed. & popd & exit /b 1 )
ghdl -r --std=08 %TOP%_tb --vcd=waveform.vcd --assert-level=error
if errorlevel 1 ( echo [ERROR] GHDL run failed or an assertion triggered. & popd & exit /b 1 )
popd
echo [SUCCESS] VHDL simulation passed. Waveform: %PRJ_DIR%\sim\waveform.vcd
exit /b 0

:sim_sv
echo [SIM:SV] Icarus Verilog, IEEE 1800-2012
if not exist "%PRJ_DIR%\sim" mkdir "%PRJ_DIR%\sim"
pushd "%PRJ_DIR%\sim"
iverilog -g2012 -s %TOP%_tb -o rtl_sim ..\src\*.sv ..\tb\*.sv
if errorlevel 1 ( echo [ERROR] Icarus Verilog compile failed. & popd & exit /b 1 )
vvp rtl_sim
if errorlevel 1 ( echo [ERROR] Icarus Verilog run failed. & popd & exit /b 1 )
popd
echo [SUCCESS] SystemVerilog simulation passed. Waveform: %PRJ_DIR%\sim\waveform.vcd
exit /b 0

:build
echo [BUILD] Synthesis + implementation for %PRJ%
if not exist "%PRJ_DIR%\build"   mkdir "%PRJ_DIR%\build"
if not exist "%PRJ_DIR%\reports" mkdir "%PRJ_DIR%\reports"
if not exist "%PRJ_DIR%\sim"     mkdir "%PRJ_DIR%\sim"
if not exist ".crash"            mkdir ".crash"
if exist "%PRJ_DIR%\build\%TOP%.bit" del /q "%PRJ_DIR%\build\%TOP%.bit"

call vivado -mode batch -notrace -journal .crash\vivado.jou -log .crash\vivado.log -source scripts\build.tcl -tclargs %PRJ_DIR% %TOP%
set BUILD_RC=!errorlevel!

if not "!BUILD_RC!"=="0" (
    echo [ERROR] Build failed. See .crash\vivado.log
    exit /b 1
)
if not exist "%PRJ_DIR%\build\%TOP%.bit" (
    echo [ERROR] Build reported success but %PRJ_DIR%\build\%TOP%.bit was not produced. See .crash\vivado.log
    exit /b 1
)
echo [SUCCESS] Bitstream and netlists generated.
exit /b 0

:sim_gate
echo [SIM:GATE] Post-route SDF-annotated timing simulation
if not exist ".crash" mkdir ".crash"
if exist "%PRJ_DIR%\sim\waveform_gate.vcd" del /q "%PRJ_DIR%\sim\waveform_gate.vcd"
call vivado -mode batch -notrace -journal .crash\xsim.jou -log .crash\xsim.log -source scripts\sim_gate.tcl -tclargs %PRJ_DIR% %TOP% %VIVADO_BASE%
if errorlevel 1 (
    echo [ERROR] Gate-level simulation failed. See .crash\xsim.log
    exit /b 1
)
if not exist "%PRJ_DIR%\sim\waveform_gate.vcd" (
    echo [ERROR] Gate-level simulation reported success but no waveform was produced. See .crash\xsim.log
    exit /b 1
)
echo [SUCCESS] Timing simulation passed.
exit /b 0

:deploy
set BIT_FILE=%PRJ_DIR%\build\%TOP%.bit
if not exist "%BIT_FILE%" (
    echo [ERROR] No bitstream found. Run: ./make.cmd build %PRJ%
    exit /b 1
)

echo This will program physical hardware over JTAG: %BIT_FILE%
set /p CONFIRM="Continue? [y/N] "
if /i not "%CONFIRM%"=="y" (
    echo Aborted.
    exit /b 1
)

call vivado -mode batch -source scripts\deploy_hw.tcl -tclargs %BIT_FILE%
if errorlevel 1 (
    echo [ERROR] Deployment failed.
    exit /b 1
)
echo [SUCCESS] Board programmed.
exit /b 0

:all
call :check_env && call :sim && call :ensure_vivado && call :build && call :sim_gate
exit /b !errorlevel!

:clean
echo [CLEAN] Purging build artifacts for %PRJ%
if exist "%PRJ_DIR%\build"          rmdir /s /q "%PRJ_DIR%\build"
if exist "%PRJ_DIR%\sim"            rmdir /s /q "%PRJ_DIR%\sim"
if exist "%PRJ_DIR%\reports"        rmdir /s /q "%PRJ_DIR%\reports"
if exist "%PRJ_DIR%\vivado_project" rmdir /s /q "%PRJ_DIR%\vivado_project"
if exist ".Xil"                     rmdir /s /q ".Xil"
if exist ".crash"                   del /q ".crash\*" >nul 2>&1
if exist "diagnostics"              del /q "diagnostics\*" >nul 2>&1
del /q *.jou *.log *.pb clockInfo.txt >nul 2>&1
exit /b 0

:tidy
echo [TIDY] Removing transient tool logs
if exist ".Xil"    rmdir /s /q ".Xil"
if exist ".crash"  del /q ".crash\*" >nul 2>&1
del /q *.jou *.log *.pb clockInfo.txt >nul 2>&1
exit /b 0

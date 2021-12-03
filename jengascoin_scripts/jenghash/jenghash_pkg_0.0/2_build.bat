@echo off
echo.
choice /c bc /n /m "Do you want to Build <b> or Clean <c> the project? (b/c)"
set INPUT=%ERRORLEVEL%
if %INPUT% EQU 1 goto build
if %INPUT% EQU 2 goto clean

:build
	python3 .\build_utils\setup.py build_ext --inplace 
	echo operation complete
	timeout /t 6 /nobreak
	exit
:clean
	python3 .\build_utils\clean_build.py
	timeout /t 6 /nobreak
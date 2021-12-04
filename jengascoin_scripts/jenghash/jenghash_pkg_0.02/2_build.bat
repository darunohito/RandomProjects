@echo off
echo.
choice /c bmc /n /m "Do you want to Build <b>, Make <m>, or Clean <c> the project? (b/m/c)"
set INPUT=%ERRORLEVEL%
if %INPUT% EQU 1 goto build
if %INPUT% EQU 2 goto make
if %INPUT% EQU 3 goto clean

:build
	python3 .\build_utils\setup.py build_ext --inplace 
	echo build operation complete
	pause
	exit
:make
	python3 .\build_utils\make.py build_ext --inplace
	echo make operation complete
	pause
	exit
:clean
	python3 .\build_utils\clean_build.py
	timeout /t 6 /nobreak
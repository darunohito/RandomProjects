@echo off
set /p wallet=Enter Wallet:
Powershell.exe -ExecutionPolicy Unrestricted -command .\php.exe -c php.ini miner pool http://pool.jengas.io %wallet%
pause
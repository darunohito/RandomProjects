@echo off
set /p wallet=Enter Wallet:
Powershell.exe -ExecutionPolicy Unrestricted -command .\php_dir\php.exe -c .\php_dir\php.ini .\php_dir\miner pool http://pool.jengas.io %wallet%
pause
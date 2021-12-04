$Threads = Read-Host -Prompt 'Enter Number of Threads'
$Wallet = Read-Host -Prompt 'Enter Wallet Address'
1..$Threads | ForEach-Object -Parallel { Powershell.exe -ExecutionPolicy Unrestricted -command .\php.exe -c "php.ini" miner pool http://pool.jengas.io/ $using:Wallet; sleep 1; } -ThrottleLimit $Threads
pause
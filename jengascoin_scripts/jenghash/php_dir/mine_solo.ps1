$Threads = Read-Host -Prompt 'Enter Number of Threads'
$Public_Key = PZ8Tyr4Nx8MHsRAGMpZmZ6TWY63dXWSCyfwKjMG1Fqak3VJQmPDWHTopuqyP7EPEkMBdE6QY4BUScCAhfxDirgmFVPLaKVAEZBuva9dNgzBAAM11YZn1ALi1
$Private_Key = Lzhp9LopCDEkxQ7ZUFp1TXif4f7cMiBk7goAV7pLfPcapiYxTu2Q591aHKcQpNvPdh4bvsceKgSQiUP7VczstGjYXKt18cFRnNBDuKHspFMWNZbdHcL183B6fQtKm7reeiMCWKCQ7vxxHeuMWSWaX7MPooURRpjRF
1..$Threads | ForEach-Object -Parallel { Powershell.exe -ExecutionPolicy Unrestricted -command .\php.exe -c "php.ini" miner solo http://peer1.jengas.io/ $using:Wallet; sleep 1; } -ThrottleLimit $Threads
pause
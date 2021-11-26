$Solo = New-Object System.Management.Automation.Host.ChoiceDescription '&Solo', 'Solo Mining'
$Pool = New-Object System.Management.Automation.Host.ChoiceDescription '&Pool', 'Pool Mining'
$options = [System.Management.Automation.Host.ChoiceDescription[]]($Solo, $Pool)
$Title = 'Mining Choices'
$message = 'How would you like to mine?'
$result = $host.ui.PromptForChoice($Title, $message, $options, 0)
switch ($result) {
        0 { Write-Host 'Max available number of threads in your computer:'(Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
$Threads = Read-Host -Prompt 'Enter Number of Threads'
#$PubKey = Read-Host -Prompt 'Enter Public Key'
#$PrivKey =Read-Host -Prompt 'Enter Private Key'
$PubKey = 'PZ8Tyr4Nx8MHsRAGMpZmZ6TWY63dXWSCyfwKjMG1Fqak3VJQmPDWHTopuqyP7EPEkMBdE6QY4BUScCAhfxDirgmFVPLaKVAEZBuva9dNgzBAAM11YZn1ALi1'
$PrivKey = 'Lzhp9LopCDEkxQ7ZUFp1TXif4f7cMiBk7goAV7pLfPcapiYxTu2Q591aHKcQpNvPdh4bvsceKgSQiUP7VczstGjYXKt18cFRnNBDuKHspFMWNZbdHcL183B6fQtKm7reeiMCWKCQ7vxxHeuMWSWaX7MPooURRpjRF'
1..$Threads | ForEach-Object -Parallel { .\php.exe -c php.ini miner solo https://peer2.jengas.io/ $using:PubKey $using:PrivKey; sleep 1; } -ThrottleLimit $Threads }
        1 { Write-Host 'Max available number of threads in your computer:'(Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
$Threads = Read-Host -Prompt 'Enter Number of Threads'
#$Wallet = Read-Host -Prompt 'Enter Wallet Address'
$Wallet = 'JAEynPtqrKuNRUNgZjN9QgbqjsDcbtQSRfZ8sd'
1..$Threads | ForEach-Object -Parallel { .\php.exe -c "php.ini" miner pool http://pool.jengas.io/ $using:Wallet; sleep 1; } -ThrottleLimit $Threads }
}
pause
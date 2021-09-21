[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$key="PZ8Tyr4Nx8MHsRAGMpZmZ6TWY63dXWSCzbcBMV5ekbQMcWmzKQm1dKTJb2UJ5cikgoRQAMW6QtPBnN3NbFueo1EDmzGTj5wfRhjmw4sdzwWonwXHTAR8qd9g"
$url="https://peer100.jengas.io/api.php?q=getBalance&public_key=$key"
$result=Invoke-WebRequest -Uri $url
Write-Host "Status code: $($result.StatusCode)"
Write-Host "Data: $($result.Content)"
cmd / pause











# Serve MathCraft: ACT Quest on your local Wi-Fi so your iPhone can install it!
# Usage: Right-click -> Run with PowerShell (or run in PowerShell)
$port = 8765
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

# Detect local Wi-Fi / LAN IPv4 address
$lanIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
  $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" -and $_.PrefixOrigin -ne "WellKnown"
} | Select-Object -First 1 -ExpandProperty IPAddress)

if (-not $lanIp) { $lanIp = "localhost" }

# Use a lightweight .NET TcpListener HTTP server so no admin URLACL reservation is required!
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $port)
$listener.Start()

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  MathCraft: ACT Quest — iPhone Wi-Fi App Server" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. On your iPhone (same Wi-Fi), open Safari and go to:" -ForegroundColor White
Write-Host "   http://$lanIp`:$port/" -ForegroundColor Yellow
Write-Host ""
Write-Host "2. Tap Share -> 'Add to Home Screen' to install as a" -ForegroundColor White
Write-Host "   full-screen offline iPhone app!" -ForegroundColor White
Write-Host ""
Write-Host "Press Ctrl+C to stop the server." -ForegroundColor Gray

$mime = @{
  ".html" = "text/html; charset=utf-8"
  ".css"  = "text/css; charset=utf-8"
  ".js"   = "application/javascript; charset=utf-8"
  ".png"  = "image/png"
  ".svg"  = "image/svg+xml"
  ".json" = "application/json; charset=utf-8"
}

try {
  while ($true) {
    $client = $listener.AcceptTcpClient()
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII, $false, 1024, $true)
    $reqLine = $reader.ReadLine()
    if ($reqLine) {
      # Drain remaining request headers
      while (($line = $reader.ReadLine()) -ne "" -and $line -ne $null) {}
      $parts = $reqLine.Split(" ")
      $reqPath = if ($parts.Length -ge 2) { $parts[1].Split("?")[0] } else { "/" }
      if ($reqPath -eq "/") { $reqPath = "/index.html" }
      $rel = $reqPath.TrimStart("/").Replace("/", "\")
      $full = Join-Path $root $rel

      if ((Test-Path $full) -and -not (Get-Item $full).PSIsContainer) {
        $ext = [System.IO.Path]::GetExtension($full).ToLower()
        $ct = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { "application/octet-stream" }
        $body = [System.IO.File]::ReadAllBytes($full)
        $hdr = "HTTP/1.1 200 OK`r`nContent-Type: $ct`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
        $hdrBytes = [System.Text.Encoding]::ASCII.GetBytes($hdr)
        $stream.Write($hdrBytes, 0, $hdrBytes.Length)
        $stream.Write($body, 0, $body.Length)
      } else {
        $hdr = "HTTP/1.1 404 Not Found`r`nContent-Length: 0`r`nConnection: close`r`n`r`n"
        $hdrBytes = [System.Text.Encoding]::ASCII.GetBytes($hdr)
        $stream.Write($hdrBytes, 0, $hdrBytes.Length)
      }
    }
    $client.Close()
  }
} finally {
  $listener.Stop()
}

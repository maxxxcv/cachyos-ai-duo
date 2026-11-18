# Writes the CachyOS ISO to the USB stick (drive F:). Must run as Administrator.
# Safety: refuses to run unless disk 2 is exactly the SanDisk Cruzer Edge USB (7.45GB) and F: is on it.
param(
  [string]$Iso = "$env:TEMP\cachy_dl\cachyos-desktop-linux-260809.iso",
  [string]$Log = "$env:TEMP\cachy_dl\write_usb.log"
)
$ErrorActionPreference = 'Stop'
Start-Transcript -Path $Log -Force | Out-Null
try {
  $disk = Get-Disk -Number 2
  $f = Get-Partition -DriveLetter F
  if ($disk.BusType -ne 'USB' -or $disk.FriendlyName -notlike '*Cruzer*' -or $disk.Size -gt 8GB -or $f.DiskNumber -ne 2 -or $disk.IsBoot -or $disk.IsSystem) {
    throw "SAFETY STOP: disk 2 is not the expected USB stick. Nothing was changed."
  }
  Write-Host "Target OK: $($disk.FriendlyName) $([math]::Round($disk.Size/1GB,2))GB USB"
  $expected = (Get-Content "$env:TEMP\cachy_dl\cachyos.iso.sha256").Split(' ')[0]
  $actual = (Get-FileHash $Iso -Algorithm SHA256).Hash
  if ($expected -ne $actual.ToLower()) { throw "SAFETY STOP: ISO checksum mismatch." }
  Write-Host "ISO checksum OK"

  Clear-Disk -Number 2 -RemoveData -RemoveOEM -Confirm:$false
  Write-Host "Stick wiped"

  $in = [IO.File]::OpenRead($Iso)
  $out = New-Object IO.FileStream('\\.\PhysicalDrive2', [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite, 4MB)
  $buf = New-Object byte[] (4MB)
  $total = $in.Length; $done = 0
  while ($done -lt $total) {
    $n = $in.Read($buf, 0, $buf.Length)
    if ($n -le 0) { break }
    $w = [int]([math]::Ceiling($n / 512.0) * 512)
    if ($w -gt $n) { [Array]::Clear($buf, $n, $w - $n) }
    $out.Write($buf, 0, $w)
    $done += $n
    if (($done / 4MB) % 100 -lt 1) { Write-Host ("{0:N0} MB" -f ($done / 1MB)) }
  }
  $out.Flush(); $out.Close(); $in.Close()
  Write-Host "WRITE DONE: $done bytes"
  Update-Disk -Number 2 -ErrorAction SilentlyContinue
  Write-Host "RESULT=OK"
} catch {
  Write-Host "RESULT=FAIL: $_"
} finally { Stop-Transcript | Out-Null }

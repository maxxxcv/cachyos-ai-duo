# Shrinks drive D: by 150 GB to leave unallocated space for a Linux install. No data is deleted.
# Must run as Administrator. Refuses to run unless D: is the 931GB WDC disk and 150GB can be freed.
param([string]$Log = "$env:TEMP\cachy_dl\shrink_d.log")
$ErrorActionPreference = 'Stop'
Start-Transcript -Path $Log -Force | Out-Null
try {
  $part = Get-Partition -DriveLetter D
  $disk = Get-Disk -Number $part.DiskNumber
  if ($disk.FriendlyName -notlike 'WDC*' -or $disk.IsSystem -or $disk.IsBoot) { throw "SAFETY STOP: D: is not on the expected data disk." }
  $sup = Get-PartitionSupportedSize -DriveLetter D
  $newSize = $part.Size - 150GB
  Write-Host ("Current: {0:N1} GB; smallest possible: {1:N1} GB; target: {2:N1} GB" -f ($part.Size/1GB), ($sup.SizeMin/1GB), ($newSize/1GB))
  if ($newSize -lt $sup.SizeMin) { throw "Cannot shrink by 150GB (unmovable files). Nothing changed." }
  Resize-Partition -DriveLetter D -Size $newSize
  $after = Get-Partition -DriveLetter D
  Write-Host ("After: D is {0:N1} GB" -f ($after.Size/1GB))
  Get-Disk -Number $disk.Number | Select Number,@{n='LargestFreeGB';e={[math]::Round($_.LargestFreeExtent/1GB,1)}} | Format-Table | Out-String | Write-Host
  Write-Host "RESULT=OK"
} catch { Write-Host "RESULT=FAIL: $_" } finally { Stop-Transcript | Out-Null }

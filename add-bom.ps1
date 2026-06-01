$src = 'D:\gongsi\claude-code-cn-installer-main\ClaudeCodeGUI.ps1'
$content = [System.IO.File]::ReadAllText($src, [System.Text.Encoding]::GetEncoding(65001))
$bom = [System.Text.Encoding]::UTF8.GetPreamble()
$encoded = [System.Text.Encoding]::UTF8.GetBytes($content)
$final = New-Object byte[] ($bom.Length + $encoded.Length)
[System.Buffer]::BlockCopy($bom, 0, $final, 0, $bom.Length)
[System.Buffer]::BlockCopy($encoded, 0, $final, $bom.Length, $encoded.Length)
[System.IO.File]::WriteAllBytes($src, $final)
Write-Host "Done. File size: $($final.Length) bytes, BOM: $($final[0]) $($final[1]) $($final[2])" -ForegroundColor Green

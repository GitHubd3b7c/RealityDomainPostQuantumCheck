# 检查 domains.txt 文件是否存在
if (!(Test-Path "domains.txt")) {
    Write-Host "Error: domains.txt file not found!" -ForegroundColor Red
    Write-Host "Please create a 'domains.txt' file with one domain per line in the same directory as this script." -ForegroundColor Yellow
    exit 1
}

# 从 domains.txt 文件读取域名列表
$domainsFromFile = Get-Content "domains.txt" | Where-Object { $_.Trim() -ne "" } | ForEach-Object { $_.Trim() }

Write-Host "Loaded $($domainsFromFile.Count) domains from domains.txt" -ForegroundColor Cyan

$supportedDomains = @()

foreach ($domain in $domainsFromFile) {
    Write-Host "Testing $domain..."
    try {
        $output = & ".\xray.exe" tls ping $domain 2>&1
        $outputString = $output | Out-String
        $lines = $outputString -split '[\r\n]' | Where-Object { $_.Trim() -ne '' }
        
        $pqValues = @()
        $lengthValues = @()
        
        foreach ($line in $lines) {
            $trimmedLine = $line.Trim()
            
            # 检查后量子密钥交换
            if ($trimmedLine -match "TLS Post-Quantum key exchange:\s*(true|false)") {
                $pqValues += $matches[1]
            }
            
            # 检查证书链长度
            if ($trimmedLine -match "Certificate chain's total length:\s*(\d+)") {
                $lengthValues += [int]$matches[1]
            }
        }
        
        # 检查是否满足两个条件：1) 两个 PQ 值都是 true，2) 两个长度值都大于 3500
        $pqCondition = $pqValues.Count -ge 2 -and $pqValues[0] -eq "true" -and $pqValues[1] -eq "true"
        $lengthCondition = $lengthValues.Count -ge 2 -and $lengthValues[0] -gt 3500 -and $lengthValues[1] -gt 3500
        
        if ($pqCondition -and $lengthCondition) {
            $supportedDomains += $domain
            Write-Host "  SUCCESS: $domain meets both criteria (PQ: $($pqValues[0]), $($pqValues[1]); Length: $($lengthValues[0]), $($lengthValues[1]))" -ForegroundColor Green
        } else {
            $pqStatus = if ($pqValues.Count -ge 2) { "$($pqValues[0]), $($pqValues[1])" } else { "only $($pqValues.Count) found" }
            $lenStatus = if ($lengthValues.Count -ge 2) { "$($lengthValues[0]), $($lengthValues[1])" } else { "only $($lengthValues.Count) found" }
            Write-Host "  FAILED: $domain (PQ: $pqStatus; Length: $lenStatus)" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  ERROR testing $domain" -ForegroundColor Red
    }
}

Write-Host "`n=== Results ===" -ForegroundColor Cyan
Write-Host "Found $($supportedDomains.Count) domains that meet both criteria:"
foreach ($domain in $supportedDomains) {
    Write-Host "  $domain"
}

# 将结果保存到 output_domain.txt
$resultFileName = "output_domain.txt"
"Results: $($supportedDomains.Count) domains found meeting both criteria" | Out-File -FilePath $resultFileName -Encoding UTF8
if ($supportedDomains.Count -gt 0) {
    $supportedDomains | Out-File -Append -FilePath $resultFileName -Encoding UTF8
}

Write-Host "`nScript completed. Results saved to $resultFileName" -ForegroundColor Green
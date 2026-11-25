# Local quality gate (Windows PowerShell): pub get, format, analyze, test.
# Usage: powershell -ExecutionPolicy Bypass -File tools\check.ps1

function Invoke-Step([string]$Name, [scriptblock]$Command) {
    Write-Host "==> $Name"
    & $Command
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: $Name"
        exit $LASTEXITCODE
    }
}

Invoke-Step 'flutter pub get' { flutter pub get }
Invoke-Step 'dart format' { dart format . }
Invoke-Step 'flutter analyze' { flutter analyze }
Invoke-Step 'flutter test' { flutter test }
Write-Host 'All checks passed.'

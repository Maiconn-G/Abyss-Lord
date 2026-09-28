# Executa todas as suítes headless do projeto em sequência e acumula o resultado.
#
# Descoberta: tests/test_*.gd em ordem alfabética. A suíte temporária de teste visual
# nunca entra nesse padrão (ela se chama _visual_probe.gd), e o filtro explícito abaixo
# mantém de fora qualquer helper ou probe que venha a existir com nome parecido.
#
# Saída por suíte: nome, exit code, PASS/FAIL e a linha-resumo que o próprio harness
# imprime ("---- <suite> tests finished: N asserts, M failure(s) ----"). A soma de
# asserts é informativa: nem toda suíte imprime contagem, então a decisão de verde ou
# vermelho vem do exit code, nunca de regex.
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File tests\run_all_tests.ps1
#   $env:GODOT_BIN = "C:\caminho\Godot_v4.6.1.exe"; powershell -File tests\run_all_tests.ps1
#
# Exit do runner: 0 se todas as suítes passaram, 1 se alguma falhou ou se o Godot não foi encontrado.

[CmdletBinding()]
param(
    [string]$ProjectPath = '',
    [string]$GodotBin = $env:GODOT_BIN
)

$ErrorActionPreference = 'Stop'

# O default do param() é avaliado no escopo do chamador, onde $PSScriptRoot ainda é vazio
# no Windows PowerShell 5.1; o caminho do projeto só pode ser derivado aqui dentro.
if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $ProjectPath = Split-Path -Parent $PSScriptRoot
}

$fallbackGodot = 'D:\Desenvolvimento\Godot_v4.6.1.exe'
if ([string]::IsNullOrWhiteSpace($GodotBin)) {
    $GodotBin = $fallbackGodot
}

if (-not (Test-Path -LiteralPath $GodotBin -PathType Leaf)) {
    Write-Host "ERRO: binário do Godot não encontrado: $GodotBin"
    Write-Host 'Defina $env:GODOT_BIN apontando para um executável do Godot 4.x.'
    Write-Host 'Nenhum Godot é baixado automaticamente.'
    exit 1
}

if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
    Write-Host "ERRO: caminho do projeto não encontrado: $ProjectPath"
    exit 1
}

$suites = Get-ChildItem -LiteralPath (Join-Path $ProjectPath 'tests') -Filter 'test_*.gd' |
    Where-Object { $_.Name -notmatch '(?i)(probe|helper|scratch|temp)' } |
    Sort-Object Name

if (-not $suites) {
    Write-Host "ERRO: nenhuma suíte test_*.gd em $(Join-Path $ProjectPath 'tests')"
    exit 1
}

$logRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'abyss_lord_test_logs'
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null

Write-Host "Godot: $GodotBin"
Write-Host "Projeto: $ProjectPath"
Write-Host "Suítes descobertas: $($suites.Count)"
Write-Host ''

$results = @()

foreach ($suite in $suites) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($suite.Name)
    $logPath = Join-Path $logRoot "$name.log"
    $godotArgs = @(
        '--headless',
        '--disable-crash-handler',
        '--path', $ProjectPath,
        '--script', "res://tests/$($suite.Name)"
    )

    $output = & $GodotBin @godotArgs 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    Set-Content -LiteralPath $logPath -Value $output

    $summary = ($output -split "`r?`n" | Where-Object { $_ -match 'tests finished:' } | Select-Object -Last 1)
    if (-not $summary) { $summary = '(sem linha de resumo)' }

    $status = if ($exitCode -eq 0) { 'PASS' } else { 'FAIL' }
    $results += [pscustomobject]@{
        Suite    = $name
        ExitCode = $exitCode
        Status   = $status
        Summary  = $summary.Trim()
    }
    Write-Host ("[{0}] {1} (exit {2}) {3}" -f $status, $name, $exitCode, $summary.Trim())
}

Write-Host ''
Write-Host '===================== RESUMO ====================='
$results | Format-Table -AutoSize Suite, ExitCode, Status, Summary | Out-String -Width 200 | Write-Host

$failed = @($results | Where-Object { $_.Status -eq 'FAIL' })
Write-Host ("total: {0} suítes | PASS: {1} | FAIL: {2}" -f $results.Count, ($results.Count - $failed.Count), $failed.Count)
Write-Host "logs: $logRoot"

if ($failed.Count -gt 0) {
    Write-Host 'suítes com falha:'
    foreach ($failure in $failed) {
        Write-Host ("  - {0} (exit {1})" -f $failure.Suite, $failure.ExitCode)
    }
    exit 1
}

exit 0

$ErrorActionPreference = 'Stop'

if (-not (Test-Path '.env')) {
    throw 'Arquivo .env ausente. Copie .env.example para .env e preencha as duas senhas locais.'
}

Get-Content '.env' | ForEach-Object {
    $configLine = $_.Trim()
    if ($configLine -and -not $configLine.StartsWith('#')) {
        $separatorIndex = $configLine.IndexOf('=')
        if ($separatorIndex -gt 0) {
            $configName = $configLine.Substring(0, $separatorIndex).Trim()
            $configValue = $configLine.Substring($separatorIndex + 1).Trim()
            [Environment]::SetEnvironmentVariable($configName, $configValue, 'Process')
        }
    }
}

foreach ($requiredName in @('POSTGRES_PASSWORD', 'POWERBI_READER_PASSWORD')) {
    if (-not [Environment]::GetEnvironmentVariable($requiredName, 'Process')) {
        throw "Preencha $requiredName no arquivo .env antes de executar."
    }
}

docker compose up -d postgres
if (-not (Test-Path '.venv\Scripts\python.exe')) {
    python -m venv .venv
}
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe scripts/load_postgres.py
.\.venv\Scripts\python.exe scripts/query_postgres.py

Write-Host ''
Write-Host 'PostgreSQL pronto para o Power BI:'
Write-Host 'Servidor: localhost:55432'
Write-Host 'Banco:    olist_analytics'
Write-Host 'Schema:   bi'
Write-Host 'Usuário:  powerbi_reader'

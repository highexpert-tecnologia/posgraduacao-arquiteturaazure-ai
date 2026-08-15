param (
    [string]$testsFolder = "tests",
    [string]$reportTitle = "Cobertura de Testes",
    [string]$sonarExclusions = "",
    [string]$runNumber = "local",
    [string]$runId = (Get-Random)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$YELLOW = "`e[33m"
$repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$resolvedTestsFolder = if ([System.IO.Path]::IsPathRooted($testsFolder)) {
    $testsFolder
}
else {
    Join-Path $repositoryRoot $testsFolder
}
$reportDirectory = Join-Path $repositoryRoot "coveragereport"

if (-not (Get-Command reportgenerator -ErrorAction SilentlyContinue)) {
    throw "ReportGenerator não encontrado. Instale com: dotnet tool install --global dotnet-reportgenerator-globaltool"
}

Write-Host "🔍 Procurando projetos de teste em: $resolvedTestsFolder"
$projects = @(Get-ChildItem -Path $resolvedTestsFolder -Recurse -Filter *.csproj -File)

if ($projects.Count -eq 0) {
    throw "Nenhum projeto de teste encontrado em '$resolvedTestsFolder'."
}

foreach ($proj in $projects) {
    Write-Host "➡️ Rodando testes com cobertura para: $($proj.FullName)"
    dotnet test $proj.FullName `
        --verbosity Minimal `
        --configuration Debug `
        --collect:"XPlat Code Coverage"

    if ($LASTEXITCODE -ne 0) {
        throw "Os testes falharam em '$($proj.FullName)'."
    }
}

Write-Host "${YELLOW}➡️ Gerando relatório HTML e Cobertura..."

reportgenerator `
    -reports:"$repositoryRoot/**/TestResults/**/coverage.cobertura.xml" `
    -targetdir:"$reportDirectory" `
    -reportTypes:"Cobertura;Html;MarkdownSummaryGithub;SonarQube" `
    -title:"$reportTitle" `
    -classfilters:"$sonarExclusions" `
    -filefilters:"-**/obj/**" `
    -tag:"${runNumber}_${runId}"

if ($LASTEXITCODE -ne 0) {
    throw "A geração do relatório de cobertura falhou."
}

Write-Host "`n✅ Processo concluído. Relatórios gerados em: $reportDirectory"

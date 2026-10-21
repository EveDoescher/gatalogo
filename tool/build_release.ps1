param(
    [Parameter(Mandatory = $true)][string]$ApiUrl,
    [ValidateSet('apk', 'appbundle', 'windows')][string]$Target = 'apk',
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$releaseUri = $null
if (-not [Uri]::TryCreate($ApiUrl, [UriKind]::Absolute, [ref]$releaseUri) -or
    $releaseUri.Scheme -notin @('http', 'https') -or
    [string]::IsNullOrWhiteSpace($releaseUri.Host) -or
    $releaseUri.UserInfo -or $releaseUri.Query -or $releaseUri.Fragment) {
    throw 'Informe uma API HTTP(S) absoluta, sem credenciais, query ou fragmento.'
}
if ($CheckOnly) {
    Write-Output 'Configuração de release válida.'
    return
}
$releaseArguments = @('build', $Target, '--release',
    "--dart-define=API_BASE_URL=$ApiUrl")
& flutter @releaseArguments
if ($LASTEXITCODE -ne 0) { throw "Build de release falhou: $LASTEXITCODE" }

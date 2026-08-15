[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$SubscriptionId,

    [string]$DisplayName = 'sp-pos-graduacao-terraform',

    [string]$CredentialOutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$microsoftGraphApplicationId = '00000003-0000-0000-c000-000000000000'
$applicationReadWriteOwnedByRoleId = '18a4783c-866b-4cc7-a460-3d5e5662c884'
$subscriptionScope = $null

function Invoke-AzJson {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $result = & az @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed: az $($Arguments -join ' ')"
    }

    return $result | ConvertFrom-Json
}

function Invoke-AzCommand {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    & az @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed: az $($Arguments -join ' ')"
    }
}

function Ensure-RoleAssignment {
    param(
        [Parameter(Mandatory)]
        [string]$PrincipalObjectId,

        [Parameter(Mandatory)]
        [string]$RoleName,

        [Parameter(Mandatory)]
        [string]$Scope
    )

    $existingAssignment = Invoke-AzJson -Arguments @(
        'role', 'assignment', 'list',
        '--assignee-object-id', $PrincipalObjectId,
        '--role', $RoleName,
        '--scope', $Scope,
        '--query', '[0]',
        '--output', 'json'
    )

    if ($null -eq $existingAssignment) {
        Invoke-AzJson -Arguments @(
            'role', 'assignment', 'create',
            '--assignee-object-id', $PrincipalObjectId,
            '--assignee-principal-type', 'ServicePrincipal',
            '--role', $RoleName,
            '--scope', $Scope,
            '--output', 'json'
        ) | Out-Null
    }
}

function ConvertTo-TerraformStringLiteral {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    return $Value.Replace('\', '\\').Replace('"', '\"').Replace("`r", '\r').Replace("`n", '\n')
}

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI (az) is required. Install it and run az login with an account authorized to assign subscription roles and grant Microsoft Graph admin consent.'
}

& az account show --output none
if ($LASTEXITCODE -ne 0) {
    throw 'Azure CLI is not authenticated. Run az login with an authorized administrator and try again.'
}

if ([string]::IsNullOrWhiteSpace($SubscriptionId)) {
    $SubscriptionId = Read-Host -Prompt 'Azure subscription ID'
}

$parsedSubscriptionId = [Guid]::Empty
if (-not [Guid]::TryParse($SubscriptionId, [ref]$parsedSubscriptionId)) {
    throw "Subscription ID '$SubscriptionId' is not a valid GUID."
}

$subscription = Invoke-AzJson -Arguments @(
    'account', 'show',
    '--subscription', $SubscriptionId,
    '--output', 'json'
)

$subscriptionScope = "/subscriptions/$($subscription.id)"
$existingApplication = Invoke-AzJson -Arguments @(
    'ad', 'app', 'list',
    '--display-name', $DisplayName,
    '--query', '[0]',
    '--output', 'json'
)

Write-Host "Subscription: $($subscription.name) ($($subscription.id))"
Write-Host "Service principal: $DisplayName"
Write-Host 'Roles: Contributor and User Access Administrator at subscription scope'
Write-Host 'Microsoft Graph application permission: Application.ReadWrite.OwnedBy'

if (-not $PSCmdlet.ShouldProcess($subscriptionScope, "Create or repair service principal '$DisplayName' and grant permissions")) {
    return
}

if ($null -eq $existingApplication) {
    $servicePrincipalCredentials = Invoke-AzJson -Arguments @(
        'ad', 'sp', 'create-for-rbac',
        '--name', $DisplayName,
        '--role', 'Contributor',
        '--scopes', $subscriptionScope,
        '--output', 'json'
    )
} else {
    Write-Warning "Using the existing App Registration '$DisplayName' and generating a new client secret."
    $servicePrincipalCredentials = Invoke-AzJson -Arguments @(
        'ad', 'app', 'credential', 'reset',
        '--id', $existingApplication.appId,
        '--append',
        '--output', 'json'
    )
}

$clientId = $servicePrincipalCredentials.appId
$servicePrincipal = Invoke-AzJson -Arguments @(
    'ad', 'sp', 'show',
    '--id', $clientId,
    '--output', 'json'
)

Ensure-RoleAssignment -PrincipalObjectId $servicePrincipal.id -RoleName 'Contributor' -Scope $subscriptionScope
Ensure-RoleAssignment -PrincipalObjectId $servicePrincipal.id -RoleName 'User Access Administrator' -Scope $subscriptionScope

Invoke-AzCommand -Arguments @(
    'ad', 'app', 'permission', 'add',
    '--id', $clientId,
    '--api', $microsoftGraphApplicationId,
    '--api-permissions', "$applicationReadWriteOwnedByRoleId=Role"
) | Out-Null

$graphServicePrincipal = Invoke-AzJson -Arguments @(
    'ad', 'sp', 'show',
    '--id', $microsoftGraphApplicationId,
    '--output', 'json'
)

$appRoleAssignment = @{
    principalId = $servicePrincipal.id
    resourceId  = $graphServicePrincipal.id
    appRoleId   = $applicationReadWriteOwnedByRoleId
} | ConvertTo-Json -Compress

$existingAppRoleAssignment = Invoke-AzJson -Arguments @(
    'rest',
    '--method', 'GET',
    '--uri', "https://graph.microsoft.com/v1.0/servicePrincipals/$($servicePrincipal.id)/appRoleAssignments",
    '--output', 'json'
)

if ($null -eq ($existingAppRoleAssignment.value | Where-Object {
            $_.resourceId -eq $graphServicePrincipal.id -and $_.appRoleId -eq $applicationReadWriteOwnedByRoleId
        })) {
    $bodyFile = New-TemporaryFile
    try {
        Set-Content -LiteralPath $bodyFile -Value $appRoleAssignment -NoNewline -Encoding utf8
        Invoke-AzJson -Arguments @(
            'rest',
            '--method', 'POST',
            '--uri', "https://graph.microsoft.com/v1.0/servicePrincipals/$($servicePrincipal.id)/appRoleAssignments",
            '--headers', 'Content-Type=application/json',
            '--body', "@$bodyFile",
            '--output', 'json'
        ) | Out-Null
    } finally {
        Remove-Item -LiteralPath $bodyFile -Force -ErrorAction SilentlyContinue
    }
}

$credentialsTfvars = @(
    "arm_client_id = `"$(ConvertTo-TerraformStringLiteral -Value $clientId)`""
    "arm_client_secret = `"$(ConvertTo-TerraformStringLiteral -Value $servicePrincipalCredentials.password)`""
    "arm_subscription_id = `"$(ConvertTo-TerraformStringLiteral -Value $subscription.id)`""
    "arm_tenant_id = `"$(ConvertTo-TerraformStringLiteral -Value $servicePrincipalCredentials.tenant)`""
) -join [Environment]::NewLine

Write-Warning 'The client secret is shown only now. Store it in a GitHub Actions secret or Azure Key Vault; do not commit it.'
Write-Output $credentialsTfvars

if (-not [string]::IsNullOrWhiteSpace($CredentialOutputPath)) {
    $outputDirectory = Split-Path -Parent $CredentialOutputPath
    if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }

    Set-Content -Path $CredentialOutputPath -Value $credentialsTfvars -NoNewline
    Write-Warning "Credentials were written to '$CredentialOutputPath'. Delete this local file after storing the secret securely."
}

Write-Host 'Assigned Azure roles:'
& az role assignment list `
    --assignee-object-id $servicePrincipal.id `
    --scope $subscriptionScope `
    --query '[].roleDefinitionName' `
    --output table

if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify Azure role assignments.'
}

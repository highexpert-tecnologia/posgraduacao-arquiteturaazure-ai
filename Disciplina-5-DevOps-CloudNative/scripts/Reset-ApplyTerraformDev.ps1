[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$terraformRoot = Split-Path -Parent $PSScriptRoot
$iacDirectory = Join-Path $terraformRoot 'IaC'
$artifacts = @(
    '.terraform',
    '.terraform.lock.hcl',
    'terraform.tfstate',
    'terraform.tfstate.backup',
    'terraform.tfstate.d'
)

foreach ($artifact in $artifacts) {
    $path = Join-Path $iacDirectory $artifact
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force
        Write-Host "Removed $artifact"
    }
}

# terraform -chdir="$iacDirectory" init
# if ($LASTEXITCODE -ne 0) {
#     throw 'Terraform init failed.'
# }

# terraform -chdir="$iacDirectory" workspace new dev || terraform -chdir="$iacDirectory" workspace select dev
# if ($LASTEXITCODE -ne 0) {
#     throw 'Terraform workspace select failed.'
# }

# terraform -chdir="$iacDirectory" apply `
#     -var-file='environments/dev.tfvars' `
#     -var-file='credential.tfvars' `
#     -auto-approve
# if ($LASTEXITCODE -ne 0) {
#     throw 'Terraform apply failed.'
# }

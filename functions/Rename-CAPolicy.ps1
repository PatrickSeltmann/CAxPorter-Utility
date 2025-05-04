function Rename-CAPolicy {
    param (
        [Parameter(Mandatory)] [object]$Policy,
        [Parameter(Mandatory)] [string]$SearchPattern,
        [Parameter(Mandatory)] [string]$Replacement,
        [switch]$DryRun
    )

    $originalName = $Policy.displayName
    $newName = [regex]::Replace($originalName, $SearchPattern, $Replacement)

    if ($originalName -ne $newName) {
        if (-not $gui) { Write-Host "Renaming '$originalName' to '$newName'" }
        if (-not $DryRun) {
            $patchBody = @{ displayName = $newName } | ConvertTo-Json -Depth 3
            Invoke-MgGraphRequest -Method PATCH `
                -Uri "https://graph.microsoft.com/beta/identity/conditionalAccess/policies/$($Policy.id)" `
                -Body $patchBody `
                -ContentType "application/json"

            $global:RenamedPolicies += $Policy.Id
            return $true
        }
    }
    return $false
}
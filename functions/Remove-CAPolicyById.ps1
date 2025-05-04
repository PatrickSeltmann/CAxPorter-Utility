function Remove-CAPolicyById {
    param (
        [Parameter(Mandatory)]
        [string]$PolicyId
    )
    try {
        Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/beta/identity/conditionalAccess/policies/$($policy.Id)" -ErrorAction Stop
        Start-Sleep -Milliseconds 1500
        If (-not $GUI) {
            Write-Host "Deleted policy: $PolicyId" -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "Failed to delete policy: $PolicyId - $($_.Exception.Message)"
    }
}
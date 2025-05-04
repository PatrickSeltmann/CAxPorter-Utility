
function GetOrCreate-TermsOfUse {
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$ToUConfig,
        [Parameter(Mandatory = $true)]
        [string]$PdfFilePath
    )

    <# 
Funktion zum Abrufen oder Erstellen von Terms of User Konfigurationen
 Für den Import einer PDF muss im Import-Verzeichnis der Policy JSON eine gleichnamige PDF Datei gespeichert sein. 

        "termsOfUse": [
        {
            "displayName": "Terms of Use for GuestAdmins"
        }
        ]
 
PDF Filename muss in diesem Fall: Terms of Use for GuestAdmins.pdf lauten.
#>

    # Prüfe, ob Terms of Use bereits existiert
    $existingToUs = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/identityGovernance/termsOfUse/agreements").value
    $existingToU = $existingToUs | Where-Object { $_.displayName -eq $ToUConfig.displayName }

    if ($existingToU) {
        Write-Host "Terms of Use '$($ToUConfig.displayName)' allready exists." -ForegroundColor Cyan
        return $existingToU.id
    }

    # PDF prüfen und Base64 kodieren
    if (-not (Test-Path -LiteralPath $PdfFilePath)) {
        throw "PDF File '$PdfFilePath' not foundn!"
    }

    try {
        $pdfContentBytes = [System.IO.File]::ReadAllBytes($PdfFilePath)
        $pdfBase64Content = [Convert]::ToBase64String($pdfContentBytes)
    }
    catch {
        throw "Error when reading or encoding the PDF file: $_"
    }

    # Aufbau nach API-Spezifikation
    $body = @{
        displayName                       = $ToUConfig.displayName
        isViewingBeforeAcceptanceRequired = if ($ToUConfig.isViewingBeforeAcceptanceRequired -ne $null) { $ToUConfig.isViewingBeforeAcceptanceRequired } else { $true }
        files                             = @(
            @{
                fileName  = [IO.Path]::GetFileName($PdfFilePath)
                isDefault = $true
                language  = "de"
                fileData  = @{
                    data = $pdfBase64Content 
                }
            }
        )
    }

    try {
        # API-Aufruf gemäß Spezifikation
        $response = Invoke-MgGraphRequest `
            -Uri "https://graph.microsoft.com/beta/identityGovernance/termsOfUse/agreements" `
            -Method POST `
            -Body ($body | ConvertTo-Json -Depth 10 -Compress) `
            -ContentType "application/json"

        If (-not $GUI) {Write-Host "Terms of Use '$($ToUConfig.displayName)' successfully created erstellt." -ForegroundColor Green}
        return $response.id
    }
    catch {
        $errorMessage = $_.Exception.Response.Content.ReadAsStringAsync().Result
        Write-Error "API error when creating the Terms of Use: $errorMessage"
        return $null
    }
}
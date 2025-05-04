    # Erweiterte Funktion zum Abrufen der vollständigen Terms of Use Konfiguration
    function Get-TermsOfUseConfiguration {
        param (
            [string]$TermsOfUseId
        )

        try {
            $ToUDetails = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/identityGovernance/termsOfUse/agreements/$TermsOfUseId" -Method GET -ErrorAction Stop

            # Vollständige Terms-of-Use-Konfiguration
            $ToUConfig = @{
                id                                = $ToUDetails.id
                displayName                       = $ToUDetails.displayName
                isViewingBeforeAcceptanceRequired = $ToUDetails.isViewingBeforeAcceptanceRequired
                isAcceptanceRequired              = $ToUDetails.isAcceptanceRequired
                expireDateTime                    = $ToUDetails.expireDateTime
                durationBeforeReacceptance        = $ToUDetails.durationBeforeReacceptance
            }

            return $ToUConfig
        }
        catch {
            Write-Error "Fehler beim Abrufen der Terms of Use für ID: $TermsOfUseId - $_"
            return @{
                id          = $TermsOfUseId
                displayName = $TermsOfUseId
            }
        }
    }
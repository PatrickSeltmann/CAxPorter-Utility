<#
.SYNOPSIS
    Imports Conditional Access Policies from JSON files into Microsoft Entra ID.

.DESCRIPTION
    This PowerShell script allows importing Conditional Access Policies from previously exported JSON files
    into a Microsoft Entra tenant. The JSON files contain complete policy definitions including references
    to groups, named locations, authentication contexts, strengths, and terms of use.

    Features:
    - Select and import policies via GUI or CLI
    - Automatically resolve or create:
      - Groups (including auto-creation if missing)
      - Named Locations
      - Authentication Strengths
      - Authentication Context Class References
      - Terms of Use including PDF upload
    - Optionally add a prefix to imported policy names
    - Set policy state (enabled, disabled, reporting-only)
    - Validation to prevent invalid configurations
    - Modular design via the `Prepare-CAPolicyImport` function

.PARAMETER InputDir
    Directory containing the JSON files to import. Required in CLI mode.

.PARAMETER CAPolicyPrefix
    Optional prefix to prepend to the name of each imported policy.

.PARAMETER SkipPolicies
    List of policy names to exclude from import. (Currently not used.)

.PARAMETER PolicyState
    Desired state of the imported policies:
    - enabledForReportingButNotEnforced
    - enabled
    - disabled

.PARAMETER GUI
    Launches an interactive GUI for selecting policies, setting state, and providing a name prefix.

.EXAMPLE
    CLI import example:
    PS C:\> .\Import-CAPolicies.ps1 -InputDir ".\Policies" -PolicyState "disabled" -CAPolicyPrefix "[Imported] "

.EXAMPLE
    GUI mode:
    PS C:\> .\Import-CAPolicies.ps1 -GUI

.NOTES
   Author: Patrick Seltmann  
   Version: 0.1.0 
   Created: 2025-05-03  
   Prerequisites: 
    - Microsoft.Graph PowerShell SDK
    - PowerShell V7
#>



param (
    [string]$CAPolicyPrefix = '',
    
    [string[]]$SkipPolicies = @(), 
    
    [Parameter()]
    [ValidateSet("enabledForReportingButNotEnforced", "enabled", "disabled")]
    [string]$PolicyState, 
    
    [Parameter()]
    [switch]$GUI, 

    [Parameter()]
    [string]$InputDir
)

begin {
    # Prüfung auf ungültige Kombinationen: GUI darf nicht mit anderen kombiniert werden
    if ($GUI -and ($PSBoundParameters.ContainsKey('InputDir') -or $PSBoundParameters.ContainsKey('SkipPolicies') -or $PSBoundParameters.ContainsKey('PolicyState'))) {
        throw "Der Parameter -GUI darf nicht gemeinsam mit -InputDir, -SkipPolicies oder -PolicyState verwendet werden."
    }

    if (-not $GUI) {
        if (-not $PSBoundParameters.ContainsKey('InputDir')) {
            throw "Der Parameter -InputDir ist erforderlich, wenn -GUI nicht verwendet wird."
        }
        if (-not $PSBoundParameters.ContainsKey('PolicyState')) {
            throw "Der Parameter -PolicyState ist erforderlich, wenn -GUI nicht verwendet wird."
        }
    }

    # Nur prüfen, ob das Eingabeverzeichnis existiert, wenn NICHT -GUI verwendet wird
    if (-not $GUI) {
        if (-Not (Test-Path -Path $InputDir)) {
            Write-Host "Das Eingabeverzeichnis $InputDir existiert nicht." -ForegroundColor Red
            exit
        }
    }


    # Load graph modules
    $RequiredModules = @(
        "Microsoft.Graph.Authentication"
    )

    foreach ($Module in $RequiredModules) {
        if (-not (Get-Module -Name $Module -ListAvailable)) {
            Install-Module $Module -Scope CurrentUser -Force
        }
        Import-Module $Module -Force -Verbose
    }

    # Verbinde dich mit der Microsoft Graph API und fordere die erforderlichen Berechtigungen an
    try {
        Connect-MgGraph -Scopes `
            'Policy.ReadWrite.ConditionalAccess', `
            'Agreement.ReadWrite.All', `
            'Agreement.Read.All', `
            'Policy.Read.All', `
            'Group.ReadWrite.All', `
            'Application.Read.All', `
            'Directory.Read.All'

    }
    catch {
        Write-Host "Fehler beim Verbinden mit der Microsoft Graph API: $($_.Exception.Message)" -ForegroundColor Red
        exit
    }

    # === functions ===

    # include functions
    . ".\.\functions\Get-GroupIdByName.ps1"
    . ".\.\functions\Get-ApplicationIdByName.ps1"
    . ".\.\functions\Get-RoleIdByName.ps1"
    . ".\.\functions\Get-UserIdByDisplayName.ps1"
    . ".\.\functions\Get-AuthenticationStrengthIdByName.ps1"
    . ".\.\functions\GetOrCreate-AuthenticationStrengthIdByName.ps1" 
    . ".\.\functions\GetOrCreate-TermsOfUse.ps1"  
    . ".\.\functions\GetOrCreate-NamedLocation.ps1"
    . ".\.\functions\GetOrCreate-AuthenticationContext.ps1"
    . ".\.\functions\Prepare-CAPolicyImport.ps1"    
    
}

process {

    if ($GUI) {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
    
        $form = New-Object System.Windows.Forms.Form
        $form.Text = "CAxPorter Utility | Import Conditional Access Policies"
        $form.Size = New-Object System.Drawing.Size(800, 720)
        $form.StartPosition = "CenterScreen"
    
        $label = New-Object System.Windows.Forms.Label
        $label.Text = "Select Conditional Access JSON- Files from InputDir:"
        $label.AutoSize = $true
        $label.Location = New-Object System.Drawing.Point(10, 10)
        $form.Controls.Add($label)
    
        $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
        $checkedListBox.Location = New-Object System.Drawing.Point(10, 40)
        $checkedListBox.Size = New-Object System.Drawing.Size(760, 400)
        $checkedListBox.DisplayMember = "DisplayName"
        $checkedListBox.CheckOnClick = $true
        $form.Controls.Add($checkedListBox)
    
        $btnSelectAll = New-Object System.Windows.Forms.Button
        $btnSelectAll.Text = "Select all"
        $btnSelectAll.Location = New-Object System.Drawing.Point(10, 450)
        $btnSelectAll.Size = New-Object System.Drawing.Size(120, 30)
        $btnSelectAll.Add_Click({
                for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
                    $checkedListBox.SetItemChecked($i, $true)
                }
            })
        $form.Controls.Add($btnSelectAll)

        $btnDeselectAll = New-Object System.Windows.Forms.Button
        $btnDeselectAll.Text = "Deselect all"
        $btnDeselectAll.Location = New-Object System.Drawing.Point(140, 450)
        $btnDeselectAll.Size = New-Object System.Drawing.Size(120, 30)
        $btnDeselectAll.Add_Click({
                for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
                    $checkedListBox.SetItemChecked($i, $false)
                }
            })
        $form.Controls.Add($btnDeselectAll)
    
        $folderLabel = New-Object System.Windows.Forms.Label
        $folderLabel.Text = "Importverzeichnis:"
        $folderLabel.Location = New-Object System.Drawing.Point(10, 490)
        $folderLabel.Size = New-Object System.Drawing.Size(120, 20)
        $form.Controls.Add($folderLabel)
    
        $textBox = New-Object System.Windows.Forms.TextBox
        $textBox.Location = New-Object System.Drawing.Point(130, 490)
        $textBox.Size = New-Object System.Drawing.Size(500, 20)
        $form.Controls.Add($textBox)

        $stateLabel = New-Object System.Windows.Forms.Label
        $stateLabel.Text = "Policy State:"
        $stateLabel.Location = New-Object System.Drawing.Point(10, 525)
        $stateLabel.Size = New-Object System.Drawing.Size(100, 20)
        $form.Controls.Add($stateLabel)

        $comboBox = New-Object System.Windows.Forms.ComboBox
        $comboBox.Location = New-Object System.Drawing.Point(120, 523)
        $comboBox.Size = New-Object System.Drawing.Size(200, 20)
        $comboBox.DropDownStyle = 'DropDownList'
        $comboBox.Items.AddRange(@("enabledForReportingButNotEnforced", "enabled", "disabled"))
        $comboBox.SelectedItem = "disabled"  # Standardwert
        $form.Controls.Add($comboBox)

        $prefixLabel = New-Object System.Windows.Forms.Label
        $prefixLabel.Text = "Policy Prefix (optional):"
        $prefixLabel.Location = New-Object System.Drawing.Point(10, 555)
        $prefixLabel.Size = New-Object System.Drawing.Size(100, 20)
        $form.Controls.Add($prefixLabel)

        $prefixBox = New-Object System.Windows.Forms.TextBox
        $prefixBox.Location = New-Object System.Drawing.Point(120, 553)
        $prefixBox.Size = New-Object System.Drawing.Size(200, 20)
        $form.Controls.Add($prefixBox)
    
        $btnBrowse = New-Object System.Windows.Forms.Button
        $btnBrowse.Text = "Browse..."
        $btnBrowse.Location = New-Object System.Drawing.Point(640, 488)
        $btnBrowse.Size = New-Object System.Drawing.Size(90, 25)
        $btnBrowse.Add_Click({
                $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
                if ($folderBrowser.ShowDialog() -eq "OK") {
                    $textBox.Text = $folderBrowser.SelectedPath
                    $textBox.SelectionStart = $textBox.Text.Length
                    $textBox.ScrollToCaret()
    
                    $checkedListBox.Items.Clear()
                    Get-ChildItem -Path $folderBrowser.SelectedPath -Filter *.json | Sort-Object Name | ForEach-Object {
                        $itemObject = [PSCustomObject]@{
                            DisplayName = $_.Name     
                            FullPath    = $_.FullName 
                        }
                        $null = $checkedListBox.Items.Add($itemObject)
                    }
                }
            })
        $form.Controls.Add($btnBrowse)
    
        $progressBar = New-Object System.Windows.Forms.ProgressBar
        $progressBar.Location = New-Object System.Drawing.Point(10, 620)
        $progressBar.Size = New-Object System.Drawing.Size(760, 20)
        $progressBar.Visible = $false
        $form.Controls.Add($progressBar)

        $progressLabel = New-Object System.Windows.Forms.Label
        $progressLabel.Location = New-Object System.Drawing.Point(10, 645)
        $progressLabel.Size = New-Object System.Drawing.Size(760, 20)
        $progressLabel.Text = ""
        $form.Controls.Add($progressLabel)
        
        $btnImport = New-Object System.Windows.Forms.Button
        $btnImport.Text = "Import"
        $btnImport.Location = New-Object System.Drawing.Point(10, 585)
        $btnImport.Size = New-Object System.Drawing.Size(120, 30)
        $btnImport.Add_Click({
                if (-not (Test-Path $textBox.Text)) {
                    [System.Windows.Forms.MessageBox]::Show("Bitte ein gültiges Importverzeichnis angeben.", "Fehler")
                    return
                }
    
                $SelectedImportFiles = @()
                               
                foreach ($item in $checkedListBox.CheckedItems) {
                    $SelectedImportFiles += $item.FullPath
                }

                if ($SelectedImportFiles.Count -eq 0) {
                    [System.Windows.Forms.MessageBox]::Show("Bitte mindestens eine Datei auswählen.", "Hinweis")
                    return
                }

                $progressBar.Maximum = $SelectedImportFiles.Count
                $progressBar.Value = 0
                $progressBar.Visible = $true

                $counter = 1
                foreach ($selectedFile in $SelectedImportFiles) {
                    $progressLabel.Text = "Importing $counter of $($SelectedImportFiles.Count) policies..."
                    [System.Windows.Forms.Application]::DoEvents()
                    
                    try {
                        $JSONContent = Get-Content -Raw -Path $selectedFile
                        $Policy = $JSONContent | ConvertFrom-Json
                        
                        $progressLabel.Text = "Importing $counter of $($SelectedImportFiles.Count) policies..."
                        [System.Windows.Forms.Application]::DoEvents()

                        Prepare-CAPolicyImport -Policy $Policy -JsonFilePath $selectedFile -PolicyState $comboBox.SelectedItem -CAPolicyPrefix $prefixBox.Text

                        $progressBar.Value = $counter
            
                    }
                    catch {
                        Write-Host "Fehler beim Verarbeiten der Datei $selectedFile : $($_.Exception.Message)" -ForegroundColor Red
                    }

                    $progressBar.Value = $counter
                    $counter++
                    Start-Sleep -Milliseconds 1000
                }
    
                if ($SelectedImportFiles.Count -eq 0) {
                    [System.Windows.Forms.MessageBox]::Show("Please select one file.", "Note")
                    return
                }
    
                $InputDir = $textBox.Text
                $progressLabel.Text = "Done"
                [System.Windows.Forms.Application]::DoEvents()
                [System.Windows.Forms.MessageBox]::Show("Import completed", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                
            })
        $form.Controls.Add($btnImport)

        $btnExit = New-Object System.Windows.Forms.Button
        $btnExit.Text = "Exit"
        $btnExit.Location = New-Object System.Drawing.Point(140, 585)
        $btnExit.Size = New-Object System.Drawing.Size(120, 30)
        $btnExit.Add_Click({ $form.Close() })
        $form.Controls.Add($btnExit)
    
        $form.ShowDialog() | Out-Null
    
        if (-not $InputDir -or $SelectedImportFiles.Count -eq 0) {
            exit
        }
    
        $JsonFiles = $SelectedImportFiles | ForEach-Object { Get-Item -LiteralPath $_ }

    }

    else {
        # Lade und erstelle jede Conditional Access Richtlinie aus den JSON-Dateien im Eingabeverzeichnis
        $JsonFiles = Get-ChildItem -Path $InputDir -Filter *.json -Recurse
        foreach ($JsonFile in $JsonFiles) {
            try {
                # Lade die JSON-Daten aus der Datei
                $JSONContent = Get-Content -Raw -Path $JsonFile.FullName
                $Policy = $JSONContent | ConvertFrom-Json
                
                If ($CAPolicyPrefix) {
                    Prepare-CAPolicyImport -Policy $Policy -JsonFilePath $JsonFile.FullName -PolicyState $PolicyState -CAPolicyPrefix $CAPolicyPrefix
                }
                else {
                    Prepare-CAPolicyImport -Policy $Policy -JsonFilePath $JsonFile.FullName -PolicyState $PolicyState
                }
                
                Write-Verbose -Verbose -Message "Deploying Conditional Access policies..."

                
            }
            catch {
                # Fehlermeldung im Falle eines Fehlers
                Write-Host "Fehler beim Verarbeiten der Datei $($JsonFile.Name): $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

end {
    if (-not $GUI) {
        Disconnect-MgGraph
        Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Cyan
    }
}
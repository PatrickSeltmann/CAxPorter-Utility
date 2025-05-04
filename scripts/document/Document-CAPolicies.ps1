<#
.SYNOPSIS
Generates Markdown documentation for Microsoft Conditional Access Policies using the OpenAI API.

.DESCRIPTION
This script connects to Microsoft Graph to retrieve all Conditional Access Policies, resolves internal references to display names (users, groups, roles, etc.), and then sends the policy definitions to the OpenAI API for generation of Markdown documentation. Output can be saved via GUI or CLI.

.PARAMETER GUI
Launches a Windows Forms GUI for interactive selection of policies and configuration.

.PARAMETER OutputDir
Specifies the directory where the documentation files should be stored (used only in CLI mode).

.PARAMETER OpenAIKey
API Key for OpenAI. Must be specified in CLI mode, must NOT be specified in GUI mode.

.EXAMPLE
.\Document-CAPolicies.ps1 -OutputDir ".\docs" -OpenAIKey "sk-xxxx..."

.EXAMPLE
.\Document-CAPolicies.ps1 -GUI

.NOTES
    Author: Patrick Seltmann  
    Version: 0.1.0 
    Created: 2025-05-03  
    Prerequisites: 
    - Microsoft.Graph PowerShell SDK
    - PowerShell V7
#>


param (
    [Parameter(Mandatory = $false)]
    [switch]$GUI,

    [Parameter(Mandatory = $false)]
    [string]$OutputDir,

    [Parameter(Mandatory = $false)]
    [string]$OpenAIKey
)

begin {
    # Ensure parameter combination is valid
    if ($GUI -and $OpenAIKey) {
        throw "When using -GUI, do not provide -OpenAIKey as a parameter."
    }

    if (-not $GUI -and -not $OpenAIKey) {
        throw "When not using -GUI, the -OpenAIKey parameter must be specified."
    }

    if (-not $GUI -and -not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    
    if (-not $GUI -and -not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    # Load all referenced helper functions
    . ".\.\functions\Resolve-CAPolicyReferences.ps1"
    . ".\.\functions\Get-AuthenticationStrengthDetails.ps1"
    . ".\.\functions\Get-TermsOfUseConfiguration.ps1"
    . ".\.\functions\Get-LocationConfiguration.ps1"   
    . ".\.\functions\GetOrCreate-AuthenticationContext.ps1"
    . ".\.\functions\Request-OpenAIMarkdown.ps1"
    . ".\.\functions\Get-GroupDisplayName.ps1"
    . ".\.\functions\Get-UserDisplayName.ps1"
    . ".\.\functions\Get-RoleDisplayName.ps1"
    . ".\.\functions\Get-ApplicationDisplayName.ps1"  

    # Load graph modules
    $RequiredModules = @(
        "Microsoft.Graph.Identity.DirectoryManagement",
        "Microsoft.Graph.Identity.SignIns",
        "Microsoft.Graph.Authentication",
        "Microsoft.Graph.Applications"   
    )

    foreach ($Module in $RequiredModules) {
        if (-not (Get-Module -Name $Module -ListAvailable)) {
            Install-Module $Module -Scope CurrentUser -Force
        }
        Import-Module $Module -Force -Verbose
    }

    try {
        # Connect to Microsoft Graph API with required permission scope
        Connect-MgGraph -Scopes 'Policy.Read.All'
    }
    catch {
        Write-Error "Connection to Microsoft Graph failed: $($_.Exception.Message)"
        exit
    }

}

process {
    if ($GUI) {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $form = New-Object System.Windows.Forms.Form
        $form.Text = "CAxPorter Utility | Document Conditional Access Policies via OpenAI API"
        $form.Size = New-Object System.Drawing.Size(800, 670)
        $form.StartPosition = "CenterScreen"

        $label = New-Object System.Windows.Forms.Label
        $label.Text = "Select Conditional Access Policies:"
        $label.Location = New-Object System.Drawing.Point(10, 10)
        $form.Controls.Add($label)

        $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
        $checkedListBox.Location = New-Object System.Drawing.Point(10, 40)
        $checkedListBox.Size = New-Object System.Drawing.Size(760, 360)
        $checkedListBox.CheckOnClick = $true
        $form.Controls.Add($checkedListBox)

        $folderLabel = New-Object System.Windows.Forms.Label
        $folderLabel.Text = "Output directory:"
        $folderLabel.Location = New-Object System.Drawing.Point(10, 455)
        $folderLabel.Size = New-Object System.Drawing.Size(120, 20)
        $form.Controls.Add($folderLabel)

        $textBox = New-Object System.Windows.Forms.TextBox
        $textBox.Location = New-Object System.Drawing.Point(130, 455)
        $textBox.Size = New-Object System.Drawing.Size(500, 20)
        $form.Controls.Add($textBox)

        $btnBrowse = New-Object System.Windows.Forms.Button
        $btnBrowse.Text = "Browse..."
        $btnBrowse.Location = New-Object System.Drawing.Point(640, 453)
        $btnBrowse.Size = New-Object System.Drawing.Size(90, 25)
        $btnBrowse.Add_Click({
                $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
                if ($folderBrowser.ShowDialog() -eq "OK") {
                    $textBox.Text = $folderBrowser.SelectedPath
                    $textBox.SelectionStart = $textBox.Text.Length
                    $textBox.ScrollToCaret()
                }
            })
        $form.Controls.Add($btnBrowse)

        $keyLabel = New-Object System.Windows.Forms.Label
        $keyLabel.Text = "OpenAI API Key:"
        $keyLabel.Location = New-Object System.Drawing.Point(10, 490)
        $keyLabel.Size = New-Object System.Drawing.Size(120, 20)
        $form.Controls.Add($keyLabel)

        $keyBox = New-Object System.Windows.Forms.TextBox
        $keyBox.Location = New-Object System.Drawing.Point(130, 490)
        $keyBox.Size = New-Object System.Drawing.Size(500, 20)
        $keyBox.UseSystemPasswordChar = $true
        $form.Controls.Add($keyBox)

        $documentButton = New-Object System.Windows.Forms.Button
        $documentButton.Text = "Document"
        $documentButton.Location = New-Object System.Drawing.Point(10, 525)
        $documentButton.Size = New-Object System.Drawing.Size(120, 30)
        $documentButton.Add_Click({
                $selectedPolicies = foreach ($item in $checkedListBox.CheckedItems) {
                    $ConditionalAccessPolicies | Where-Object { $_.DisplayName -eq $item }
                }
                $path = $textBox.Text
                $key = $keyBox.Text
                if (-not $key) {
                    [System.Windows.Forms.MessageBox]::Show("Please enter your OpenAI API key.", "Missing API Key")
                    return
                }
                if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path | Out-Null }

                $progressBar = New-Object System.Windows.Forms.ProgressBar
                $progressBar.Location = New-Object System.Drawing.Point(10, 560)
                $progressBar.Size = New-Object System.Drawing.Size(760, 20)
                $progressBar.Minimum = 0
                $progressBar.Maximum = $selectedPolicies.Count
                $progressBar.Value = 0
                $counter = 1
                $form.Controls.Add($progressBar)
                $progressBar.Visible = $true

                $progressLabel = New-Object System.Windows.Forms.Label
                $progressLabel.Location = New-Object System.Drawing.Point(10, 585)
                $progressLabel.Size = New-Object System.Drawing.Size(760, 20)
                $progressLabel.Text = ""
                $form.Controls.Add($progressLabel)
                
                foreach ($Policy in $selectedPolicies) {
                    $name = $Policy.DisplayName -replace '[\/\:*?"<>|]', '_'

                    # Enrich the policy JSON with display names and resolve references
                    $Processed = Resolve-CAPolicyReferences -Policy $Policy
                    $json = $Processed | ConvertTo-Json -Depth 10 -Compress
                    
                    # Call OpenAI API to generate Markdown documentation from the JSON
                    $md = Request-OpenAIMarkdown -PolicyName $name -CAPolicyJSON $json -Key $key -Endpoint "https://api.openai.com/v1/chat/completions"
                    if ($md) {
                        # Save the generated Markdown content to the specified file
                        $md | Out-File "$path\$name.md" -Encoding utf8
                    }
                    
                    # Update progress
                    $progressBar.Value = $counter
                    $progressLabel.Text = "Processing $counter of $($selectedPolicies.Count) policies..."
                    [System.Windows.Forms.Application]::DoEvents()
    
                    $counter++
                    Start-Sleep -Milliseconds 1500
            
                }
                $progressLabel.Text = "Done"
                [System.Windows.Forms.Application]::DoEvents()
                [System.Windows.Forms.MessageBox]::Show("Documentation completed.", "Done")
                
            })
        $form.Controls.Add($documentButton)

        $exitButton = New-Object System.Windows.Forms.Button
        $exitButton.Text = "Exit"
        $exitButton.Location = New-Object System.Drawing.Point(140, 525)
        $exitButton.Size = New-Object System.Drawing.Size(120, 30)
        $exitButton.Add_Click({ $form.Close() })
        $form.Controls.Add($exitButton)

        $ConditionalAccessPolicies = (Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/beta/identity/conditionalAccess/policies').value | Sort-Object DisplayName
        $ConditionalAccessPolicies | ForEach-Object {
            $null = $checkedListBox.Items.Add($_.DisplayName)
        }

        $form.ShowDialog() | Out-Null
    }
    else {
        foreach ($Policy in $ConditionalAccessPolicies) {
            $name = $Policy.DisplayName -replace '[\/\:*?"<>|]', '_'
            $Processed = Resolve-CAPolicyReferences -Policy $Policy
            $json = $Processed | ConvertTo-Json -Depth 10 -Compress
            $md = Request-OpenAIMarkdown -PolicyName $name -CAPolicyJSON $json -Key $OpenAIKey
            if ($md) {
                $md | Out-File "$OutputDir\$name.md" -Encoding utf8
                Write-Host "Documented: $name" -ForegroundColor Cyan
            }
            Start-Sleep -Milliseconds 1500
        }
    }
}

end {
    if (-not $GUI) {
        Disconnect-MgGraph
        Write-Host "Connection to Microsoft Graph has been closed." -ForegroundColor Yellow
    }
}

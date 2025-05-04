function Load-CAPolicies {
    param (
        [switch]$EnableHighlighting
    )

    $listView.Items.Clear()
    $ConditionalAccessPolicies = Get-CAPolicies | Sort-Object DisplayName

    foreach ($policy in $ConditionalAccessPolicies) {
        $item = New-Object System.Windows.Forms.ListViewItem($policy.displayName)
        $item.Tag = $policy

        if ($EnableHighlighting -and $global:RenamedPolicies -contains $policy.id) {
            $item.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 8.25, [System.Drawing.FontStyle]::Bold)
        } else {
            $item.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 8.25, [System.Drawing.FontStyle]::Regular)
        }

        $listView.Items.Add($item) | Out-Null
    }
}

# Import invoke-atomicredteam module, launch AtomicSetup if not found
try {
    Import-Module invoke-atomicredteam -ErrorAction Stop
    Write-Host "invoke-atomicredteam module successfully imported."
}
catch {
    Write-Host "invoke-atomicredteam module not found. Running AtomicSetup.ps1..."
    .\AtomicSetup.ps1
}

Add-Type -AssemblyName PresentationFramework

# Function to show a popup message
function Show-PopupMessage {
    param (
        [string]$message,
        [string]$title = "Notification"
    )
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    [System.Windows.Forms.MessageBox]::Show($message, $title, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
}

# Function to check if Atomics are ready
function Check-AtomicsReady {
    param (
        [string]$atomicRedTeamPath
    )
    $createRemoteThreadPath = Join-Path -Path $atomicRedTeamPath -ChildPath "atomics\T1055\bin\x64\CreateRemoteThread.exe"
    if (-not (Test-Path $createRemoteThreadPath)) {
        Show-PopupMessage -message "Atomics are not ready. Reinstall to resume testing."
        .\AtomicSetup.ps1
        return $false
    }
    return $true
}

# Function to search for the AtomicRedTeam directory in the root of available drives
function Find-AtomicRedTeamDirectory {
    $drives = Get-PSDrive -PSProvider FileSystem
    foreach ($drive in $drives) {
        $path = Join-Path -Path $drive.Root -ChildPath "AtomicRedTeam"
        if (Test-Path $path) {
            return $path
        }
    }
    write-host "Atomics Armed and Ready"
    return $null
}

# Function to load CSV content and update deduplicated content
function Load_CsvContent {
    param (
        [string]$csvPath
    )
    if (-not (Test-Path $csvPath)) {
        Write-Host "CSV file not found at $csvPath."
        exit
    }

    # Load the CSV content into memory
    $csvContent = Import-Csv -Path $csvPath

    # Do not deduplicate by Test GUID and keep all entries separate
    $global:deduplicatedContent = $csvContent | Sort-Object "Technique #", { [int]($_."Test #") }
}

# Function to create and show the campaign viewer GUI
function Show-CampaignViewerGUI {
    param (
        [string]$csvPath
    )

    $campaignWindow = New-Object System.Windows.Window
    $campaignWindow.Title = "Current Campaign"
    $campaignWindow.Width = 1200
    $campaignWindow.Height = 800
    $campaignWindow.WindowStartupLocation = 'CenterScreen'
    $campaignWindow.Background = [System.Windows.Media.Brushes]::Black
    $campaignWindow.Foreground = [System.Windows.Media.Brushes]::SeaGreen

    $dockPanel = New-Object System.Windows.Controls.DockPanel
    $campaignWindow.Content = $dockPanel

    # Top Panel for Delete Button
    $topPanel = New-Object System.Windows.Controls.StackPanel
    $topPanel.Orientation = 'Horizontal'
    $topPanel.HorizontalAlignment = 'Center'
    $topPanel.Margin = [System.Windows.Thickness]::new(10)
    $dockPanel.Children.Add($topPanel)
    [System.Windows.Controls.DockPanel]::SetDock($topPanel, 'Top')

    $deleteButton = New-Object System.Windows.Controls.Button
    $deleteButton.Content = "Delete Selected Rows"
    $deleteButton.Width = 150
    $deleteButton.Height = 30
    $deleteButton.Margin = [System.Windows.Thickness]::new(10)
    $deleteButton.Background = [System.Windows.Media.Brushes]::SeaGreen
    $deleteButton.Foreground = [System.Windows.Media.Brushes]::Black
    $deleteButton.Add_Click({
        $selectedItems = $listBox.SelectedItems
        if ($selectedItems.Count -gt 0) {
            $remainingItems = $listBox.Items | Where-Object { $selectedItems -notcontains $_ }
            $remainingItems | Export-Csv -Path $csvPath -NoTypeInformation -Force
            $listBox.Items.Clear()
            $remainingItems | ForEach-Object { $listBox.Items.Add($_) }
            [System.Windows.MessageBox]::Show("Selected rows deleted and CSV updated.", "Success", "OK", "Information")
        } else {
            [System.Windows.MessageBox]::Show("No rows selected for deletion.", "Error", "OK", "Error")
        }
    })
    $topPanel.Children.Add($deleteButton)

    # ListBox for displaying CSV content
    $listBox = New-Object System.Windows.Controls.ListBox
    $listBox.SelectionMode = 'Extended'
    $listBox.Background = [System.Windows.Media.Brushes]::Black
    $listBox.Foreground = [System.Windows.Media.Brushes]::SeaGreen
    $dockPanel.Children.Add($listBox)

    # Load and display CSV content
    if (Test-Path $csvPath) {
        $csvContent = Import-Csv -Path $csvPath
        $csvContent | ForEach-Object {
            $listBox.Items.Add($_)
        }
    } else {
        [System.Windows.MessageBox]::Show("CSV file not found at $csvPath.", "Error", "OK", "Error")
    }

    $campaignWindow.ShowDialog() | Out-Null
}

# Function to create and show the main GUI
function Show-MainGUI {
    Add-Type -AssemblyName PresentationFramework

    $window = New-Object System.Windows.Window
    $window.Title = "Atomic Campaign Builder"
    $window.Width = 800
    $window.Height = 800
    $window.WindowStartupLocation = 'CenterScreen'
    $window.Background = [System.Windows.Media.Brushes]::Black
    $window.Foreground = [System.Windows.Media.Brushes]::SeaGreen

    $dockPanel = New-Object System.Windows.Controls.DockPanel
    $window.Content = $dockPanel

    # Top Panel for Build Button and Output Path Input
    $topPanel = New-Object System.Windows.Controls.StackPanel
    $topPanel.Orientation = 'Horizontal'
    $topPanel.HorizontalAlignment = 'Center'
    $topPanel.Margin = [System.Windows.Thickness]::new(10)
    $dockPanel.Children.Add($topPanel)
    [System.Windows.Controls.DockPanel]::SetDock($topPanel, 'Top')

    $outputLabel = New-Object System.Windows.Controls.Label
    $outputLabel.Content = "Output Path:"
    $outputLabel.Foreground = 'SeaGreen'
    $outputLabel.Background = 'Black'
    $outputLabel.Margin = [System.Windows.Thickness]::new(10)
    $topPanel.Children.Add($outputLabel)

    $outputTextBox = New-Object System.Windows.Controls.TextBox
    $outputTextBox.Width = 200
    $outputTextBox.Margin = [System.Windows.Thickness]::new(10)
    $outputTextBox.Foreground = 'SeaGreen'
    $outputTextBox.Background = 'Black'
    $outputTextBox.BorderBrush = 'SeaGreen'
    $outputTextBox.Text = ".\AtomicCampaign.csv"
    $topPanel.Children.Add($outputTextBox)

    $newCampaignButton = New-Object System.Windows.Controls.Button
    $newCampaignButton.Content = "New Campaign"
    $newCampaignButton.Width = 100
    $newCampaignButton.Height = 30
    $newCampaignButton.Margin = [System.Windows.Thickness]::new(10)
    $newCampaignButton.Background = [System.Windows.Media.Brushes]::SeaGreen
    $newCampaignButton.Foreground = [System.Windows.Media.Brushes]::Black
    $newCampaignButton.Add_Click({
        $selectedTechniques = @()
        $checkboxes | Where-Object { $_.IsChecked -eq $true } | ForEach-Object {
            $content = $_.Content.Text
            $selectedTechniques += [PSCustomObject]@{
                "Tactic"        = [regex]::Match($content, 'Tactic: ([^\n]+)').Groups[1].Value
                "Technique #"   = [regex]::Match($content, 'Technique: (\S+)').Groups[1].Value
                "Technique Name"= [regex]::Match($content, 'Technique: \S+ - ([^\n]+)').Groups[1].Value
                "Test #"        = [regex]::Match($content, 'Test: (\S+)').Groups[1].Value
                "Test Name"     = [regex]::Match($content, 'Test: \S+ - ([^\n]+)').Groups[1].Value
                "Test GUID"     = [regex]::Match($content, 'Test GUID: (\S+)').Groups[1].Value
            }
        }

        if ($selectedTechniques.Count -gt 0) {
            $outputPath = $outputTextBox.Text
            if ($outputPath -eq "") {
                $outputPath = ".\AtomicCampaign.csv"
            }
            $selectedTechniques | Export-Csv -Path $outputPath -NoTypeInformation -Force
            [System.Windows.MessageBox]::Show("New campaign CSV created successfully at $outputPath", "Success", "OK", "Information")
        } else {
            [System.Windows.MessageBox]::Show("No techniques selected.", "Error", "OK", "Error")
        }
    })
    $topPanel.Children.Add($newCampaignButton)

    $addToCampaignButton = New-Object System.Windows.Controls.Button
    $addToCampaignButton.Content = "Add to Campaign"
    $addToCampaignButton.Width = 100
    $addToCampaignButton.Height = 30
    $addToCampaignButton.Margin = [System.Windows.Thickness]::new(10)
    $addToCampaignButton.Background = [System.Windows.Media.Brushes]::SeaGreen
    $addToCampaignButton.Foreground = [System.Windows.Media.Brushes]::Black
    $addToCampaignButton.Add_Click({
        $selectedTechniques = @()
        $checkboxes | Where-Object { $_.IsChecked -eq $true } | ForEach-Object {
            $content = $_.Content.Text
            $selectedTechniques += [PSCustomObject]@{
                "Tactic"        = [regex]::Match($content, 'Tactic: ([^\n]+)').Groups[1].Value
                "Technique #"   = [regex]::Match($content, 'Technique: (\S+)').Groups[1].Value
                "Technique Name"= [regex]::Match($content, 'Technique: \S+ - ([^\n]+)').Groups[1].Value
                "Test #"        = [regex]::Match($content, 'Test: (\S+)').Groups[1].Value
                "Test Name"     = [regex]::Match($content, 'Test: \S+ - ([^\n]+)').Groups[1].Value
                "Test GUID"     = [regex]::Match($content, 'Test GUID: (\S+)').Groups[1].Value
            }
        }

        if ($selectedTechniques.Count -gt 0) {
            $outputPath = $outputTextBox.Text
            if ($outputPath -eq "") {
                $outputPath = ".\AtomicCampaign.csv"
            }
            if (Test-Path $outputPath) {
                $existingContent = Import-Csv -Path $outputPath
                $selectedTechniques = $existingContent + $selectedTechniques
            }
            $selectedTechniques | Export-Csv -Path $outputPath -NoTypeInformation -Force
            [System.Windows.MessageBox]::Show("Selected techniques added to CSV at $outputPath", "Success", "OK", "Information")
        } else {
            [System.Windows.MessageBox]::Show("No techniques selected.", "Error", "OK", "Error")
        }
    })
    $topPanel.Children.Add($addToCampaignButton)

    $viewCampaignButton = New-Object System.Windows.Controls.Button
    $viewCampaignButton.Content = "View Campaign"
    $viewCampaignButton.Width = 100
    $viewCampaignButton.Height = 30
    $viewCampaignButton.Margin = [System.Windows.Thickness]::new(10)
    $viewCampaignButton.Background = [System.Windows.Media.Brushes]::SeaGreen
    $viewCampaignButton.Foreground = [System.Windows.Media.Brushes]::Black
    $viewCampaignButton.Add_Click({
        Show-CampaignViewerGUI -csvPath $outputTextBox.Text
    })
    $topPanel.Children.Add($viewCampaignButton)

    # Filter Panel for Tactic, Technique, and Keyword filters
    $filterPanel = New-Object System.Windows.Controls.StackPanel
    $filterPanel.Orientation = 'Horizontal'
    $filterPanel.HorizontalAlignment = 'Center'
    $filterPanel.Margin = [System.Windows.Thickness]::new(10)
    $dockPanel.Children.Add($filterPanel)
    [System.Windows.Controls.DockPanel]::SetDock($filterPanel, 'Top')

    $tacticComboBox = New-Object System.Windows.Controls.ComboBox
    $tacticComboBox.Width = 150
    $tacticComboBox.Margin = [System.Windows.Thickness]::new(10)
    $tacticComboBox.Foreground = 'SeaGreen'
    $tacticComboBox.Background = 'Black'
    $tacticComboBox.BorderBrush = 'SeaGreen'
    $tacticComboBox.HorizontalContentAlignment = 'Center'
    $tacticComboBox.Items.Add("All Tactics")
    $global:deduplicatedContent | ForEach-Object {
        if (-not $tacticComboBox.Items.Contains($_.Tactic)) {
            $tacticComboBox.Items.Add($_.Tactic)
        }
    }
    $tacticComboBox.SelectedIndex = 0
    $filterPanel.Children.Add($tacticComboBox)

    $techniqueComboBox = New-Object System.Windows.Controls.ComboBox
    $techniqueComboBox.Width = 150
    $techniqueComboBox.Margin = [System.Windows.Thickness]::new(10)
    $techniqueComboBox.Foreground = 'SeaGreen'
    $techniqueComboBox.Background = 'Black'
    $techniqueComboBox.BorderBrush = 'SeaGreen'
    $techniqueComboBox.HorizontalContentAlignment = 'Center'
    $techniqueComboBox.Items.Add("All Techniques")
    $global:deduplicatedContent | ForEach-Object {
        if (-not $techniqueComboBox.Items.Contains($_."Technique #")) {
            $techniqueComboBox.Items.Add($_."Technique #")
        }
    }
    $techniqueComboBox.SelectedIndex = 0
    $filterPanel.Children.Add($techniqueComboBox)

    $keywordTextBox = New-Object System.Windows.Controls.TextBox
    $keywordTextBox.Width = 150
    $keywordTextBox.Margin = [System.Windows.Thickness]::new(10)
    $keywordTextBox.Foreground = 'SeaGreen'
    $keywordTextBox.Background = 'Black'
    $keywordTextBox.BorderBrush = 'SeaGreen'
    $filterPanel.Children.Add($keywordTextBox)

    $keywordButton = New-Object System.Windows.Controls.Button
    $keywordButton.Content = "Search"
    $keywordButton.Width = 80
    $keywordButton.Height = 30
    $keywordButton.Margin = [System.Windows.Thickness]::new(10)
    $keywordButton.Background = [System.Windows.Media.Brushes]::SeaGreen
    $keywordButton.Foreground = [System.Windows.Media.Brushes]::Black
    $keywordButton.Add_Click({
        Add-Techniques $tacticComboBox.SelectedItem $techniqueComboBox.SelectedItem $keywordTextBox.Text
    })
    $filterPanel.Children.Add($keywordButton)

    # ScrollViewer for Techniques
    $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
    $scrollViewer.VerticalScrollBarVisibility = 'Auto'
    $scrollViewer.HorizontalScrollBarVisibility = 'Disabled'
    $dockPanel.Children.Add($scrollViewer)

    $stackPanel = New-Object System.Windows.Controls.StackPanel
    $scrollViewer.Content = $stackPanel

    # Add techniques to the list
    $checkboxes = New-Object System.Collections.ArrayList
    function Add-Techniques {
        param (
            $filterTactic,
            $filterTechnique,
            $filterKeyword
        )
        $stackPanel.Children.Clear()
        $filteredContent = $global:deduplicatedContent | Where-Object { 
            ($filterTactic -eq "All Tactics" -or $_.Tactic -eq $filterTactic) -and
            ($filterTechnique -eq "All Techniques" -or $_."Technique #" -eq $filterTechnique) -and
            ($filterKeyword -eq "" -or $_."Test Name" -like "*$filterKeyword*" -or $_."Technique Name" -like "*$filterKeyword*" -or $_."Tactic" -like "*$filterKeyword*")
        }
        $filteredContent | ForEach-Object {
            $technique = $_
            $textBlock = New-Object System.Windows.Controls.TextBlock
            $textBlock.Text = "Technique: $($technique.'Technique #') - $($technique.'Technique Name')`nTest: $($technique.'Test #') - $($technique.'Test Name')`nTactic: $($technique.Tactic)`nTest GUID: $($technique.'Test GUID')"
            $textBlock.Margin = [System.Windows.Thickness]::new(10)
            $textBlock.TextWrapping = 'Wrap'

            $checkbox = New-Object System.Windows.Controls.CheckBox
            $checkbox.Content = $textBlock
            $checkbox.Foreground = [System.Windows.Media.Brushes]::SeaGreen
            $checkbox.Margin = [System.Windows.Thickness]::new(10)
            $stackPanel.Children.Add($checkbox)
            $checkboxes.Add($checkbox) | Out-Null
        }
    }

    # Add event handlers for tactic and technique filters
    $tacticComboBox.Add_SelectionChanged({
        Add-Techniques $tacticComboBox.SelectedItem $techniqueComboBox.SelectedItem $keywordTextBox.Text
        # Update technique filter based on tactic selection
        $techniqueComboBox.Items.Clear()
        $techniqueComboBox.Items.Add("All Techniques")
        $global:deduplicatedContent | Where-Object { $_.Tactic -eq $tacticComboBox.SelectedItem -or $tacticComboBox.SelectedItem -eq "All Tactics" } | ForEach-Object {
            if (-not $techniqueComboBox.Items.Contains($_."Technique #")) {
                $techniqueComboBox.Items.Add($_."Technique #")
            }
        }
        $techniqueComboBox.SelectedIndex = 0
    })

    $techniqueComboBox.Add_SelectionChanged({
        Add-Techniques $tacticComboBox.SelectedItem $techniqueComboBox.SelectedItem $keywordTextBox.Text
    })

    # Load initial techniques
    Add-Techniques "All Tactics" "All Techniques" ""

    $window.ShowDialog() | Out-Null
}

# Load initial CSV content
$atomicRedTeamPath = Find-AtomicRedTeamDirectory
if ($atomicRedTeamPath -and (Check-AtomicsReady -atomicRedTeamPath $atomicRedTeamPath)) {
    $indexCsvPath = Join-Path -Path $atomicRedTeamPath -ChildPath "atomics\Indexes\Indexes-CSV\index.csv"
    Load_CsvContent -csvPath $indexCsvPath

    # Show the main GUI
    Show-MainGUI
}

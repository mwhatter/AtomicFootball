Add-Type -AssemblyName PresentationFramework

# Function to log messages
function Log_Message {
    param (
        [string]$message,
        [string]$type = "INFO"
    )
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $logEntry = "$timestamp [$type] - $message"
    Add-Content -Path "$env:APPDATA\MainInterfaceLog.txt" -Value $logEntry
    Write-Host $logEntry
}

# Function to run a script
function Run_Script {
    param (
        [string]$scriptPath
    )
    try {
        if (-not (Test-Path $scriptPath)) {
            Log_Message "Script file not found: $scriptPath" "ERROR"
            [System.Windows.MessageBox]::Show("Script file not found: $scriptPath", "Error", "OK", "Error")
            return
        }

        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = "powershell.exe"
        $processInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        $processInfo.RedirectStandardError = $true
        $processInfo.RedirectStandardOutput = $true
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null
        $output = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()

        Log_Message "Script output: $output"
        if ($stderr) {
            Log_Message "Script stderr: $stderr" "ERROR"
        }
    } catch {
        Log_Message "Error running script: $scriptPath, Exception: $_" "ERROR"
        [System.Windows.MessageBox]::Show("Error running script: $scriptPath", "Error", "OK", "Error")
    }
}

# Function to create and show the main GUI
function Show-MainGUI {
    $window = New-Object System.Windows.Window
    $window.Title = "Atomic Base"
    $window.Width = 420
    $window.Height = 420
    $window.WindowStartupLocation = 'CenterScreen'
    $window.Foreground = 'SeaGreen'
    $window.Background = 'Black'

    $stackPanel = New-Object System.Windows.Controls.StackPanel
    $stackPanel.HorizontalAlignment = 'Center'
    $stackPanel.VerticalAlignment = 'Center'
    $stackPanel.Margin = [System.Windows.Thickness]::new(10)
    $window.Content = $stackPanel

    $buttonWidth = 200
    $buttonHeight = 40
    $buttonMargin = [System.Windows.Thickness]::new(10)

    $campaignBuilderButton = New-Object System.Windows.Controls.Button
    $campaignBuilderButton.Content = "Atomic Campaign Builder"
    $campaignBuilderButton.Width = $buttonWidth
    $campaignBuilderButton.Height = $buttonHeight
    $campaignBuilderButton.Margin = $buttonMargin
    $campaignBuilderButton.Background = 'SeaGreen'
    $campaignBuilderButton.Foreground = 'Black'
    $campaignBuilderButton.Add_Click({
        Run_Script -scriptPath ".\AtomicCampaignBuilder.ps1"
    })
    $stackPanel.Children.Add($campaignBuilderButton)

    $campaignRunnerButton = New-Object System.Windows.Controls.Button
    $campaignRunnerButton.Content = "Atomic Campaign Runner"
    $campaignRunnerButton.Width = $buttonWidth
    $campaignRunnerButton.Height = $buttonHeight
    $campaignRunnerButton.Margin = $buttonMargin
    $campaignRunnerButton.Background = 'SeaGreen'
    $campaignRunnerButton.Foreground = 'Black'
    $campaignRunnerButton.Add_Click({
        Run_Script -scriptPath ".\AtomicCampaignRunner.ps1"
    })
    $stackPanel.Children.Add($campaignRunnerButton)

    $executionButton = New-Object System.Windows.Controls.Button
    $executionButton.Content = "Atomic Sniper"
    $executionButton.Width = $buttonWidth
    $executionButton.Height = $buttonHeight
    $executionButton.Margin = $buttonMargin
    $executionButton.Background = 'SeaGreen'
    $executionButton.Foreground = 'Black'
    $executionButton.Add_Click({
        Run_Script -scriptPath ".\AtomicSniper.ps1"
    })
    $stackPanel.Children.Add($executionButton)

    $setupButton = New-Object System.Windows.Controls.Button
    $setupButton.Content = "Atomic Setup"
    $setupButton.Width = $buttonWidth
    $setupButton.Height = $buttonHeight
    $setupButton.Margin = $buttonMargin
    $setupButton.Background = 'SeaGreen'
    $setupButton.Foreground = 'Black'
    $setupButton.Add_Click({
        Run_Script -scriptPath ".\AtomicSetup.ps1"
    })
    $stackPanel.Children.Add($setupButton)

    $exclusionHelperButton = New-Object System.Windows.Controls.Button
    $exclusionHelperButton.Content = "Exclusion Helper"
    $exclusionHelperButton.Width = $buttonWidth
    $exclusionHelperButton.Height = $buttonHeight
    $exclusionHelperButton.Margin = $buttonMargin
    $exclusionHelperButton.Background = 'SeaGreen'
    $exclusionHelperButton.Foreground = 'Black'
    $exclusionHelperButton.Add_Click({
        Run_Script -scriptPath ".\ExclusionHelper.ps1"
    })
    $stackPanel.Children.Add($exclusionHelperButton)

    $window.ShowDialog() | Out-Null
}

# Show the main GUI
Show-MainGUI

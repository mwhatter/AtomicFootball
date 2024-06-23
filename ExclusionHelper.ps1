# Function to search for the AtomicRedTeam directory in the root of available drives
function Find-AtomicRedTeamDirectory {
    $drives = Get-PSDrive -PSProvider FileSystem
    foreach ($drive in $drives) {
        $path = Join-Path -Path $drive.Root -ChildPath "AtomicRedTeam"
        if (Test-Path $path) {
            return $path
        }
    }
    return "C:\AtomicRedTeam"
}

# Find the AtomicRedTeam directory
$atomicRedTeamDir = Find-AtomicRedTeamDirectory
if (-not $atomicRedTeamDir) {
    Write-Host "AtomicRedTeam directory not found. Defaulting to C:\AtomicRedTeam."
}

# Define the list of processes to check with references
$processes = @{
    "EDR - CrowdStrike" = @{
        Processes = @("csagent", "falcon-sensor", "falconhost", "falcond", "falconagent", "CSFalconContainer", "CSFalconService")
        Command = "No specific command-line arguments for adding exclusions."
        Reference = "https://help.redcanary.com/hc/en-us/articles/360002531153-How-to-Create-Exclusions-in-CrowdStrike"
    }
    "EDR - Carbon Black" = @{
        Processes = @("cbagent", "cbdefense", "cbcomms", "cbstream", "cbdaemon")
        Command = "Edit the `cb.conf` file and restart the service."
        Reference = "https://docs.vmware.com/en/VMware-Carbon-Black-EDR/7.8.0/vmw-cb-edr-ug/GUID-3B294CB3-085E-430F-B3F3-DF1F08D11209.html"
    }
    "EDR - SentinelOne" = @{
        Processes = @("SentinelAgent", "SentinelHelperService", "SentinelCleaner")
        Command = "SentinelCtl.exe exclude -p '$atomicRedTeamDir'"
        Reference = "https://www.sonicwall.com/support/knowledge-base/sentinelone-agent-command-line-tool/200127110543726/"
    }
    "EDR - FireEye" = @{
        Processes = @("xagt", "xagtnotif", "xagt_helper")
        Command = "No direct command-line arguments for adding exclusions."
        Reference = "https://docs.fireeye.com/"
    }
    "EDR - Symantec" = @{
        Processes = @("sisips", "smc", "ccSvcHst", "SepMasterService", "sesmagt")
        Command = "symcfg add -k '\\Symantec Endpoint Protection\\AV\\Storages\\FileSystem\\RealTimeScan\\NoScanDir' -v $atomicRedTeamDir -d 1 -t REG_DWORD"
        Reference = "https://knowledge.broadcom.com/external/article/156028/configuring-exceptions-policies-in-endpo.html"
    }
    "EDR - McAfee" = @{
        Processes = @("mfetp", "mcshield", "mfewc", "masvc", "mfeann")
        Command = "cmdagent.exe /P"
        Reference = "https://docs.mcafee.com/bundle/endpoint-security-10.7.0-client-command-line-reference-guide/page/GUID-6A89B8F3-3C7D-4A84-B16A-C9ACD2C1D7B8.html"
    }
    "EDR - Sophos" = @{
        Processes = @("savservice", "SAVAdminService", "SophosClean", "SophosEDR")
        Command = "savconfig add Exclusion -p '$atomicRedTeamDir'"
        Reference = "https://docs.sophos.com/esg/enterprise-console/5-12/help/en-us/esg/Enterprise-Console/tasks/UseCommandLineTools.html"
    }
    "EDR - Microsoft Defender ATP" = @{
        Processes = @("MsMpEng", "Sense", "MsSense", "WdNisSvc", "MpCmdRun", "DefenderUI")
        Command = "Add-MpPreference -ExclusionPath '$atomicRedTeamDir'"
        Reference = "https://docs.microsoft.com/en-us/microsoft-365/security/defender-endpoint/configure-extension-file-exclusions-microsoft-defender-antivirus"
    }
    "EDR - Trend Micro" = @{
        Processes = @("PccNTMon", "TMBMSRV", "TmListen", "TmPfw", "TmProxy")
        Command = "TmiCmd.exe -AddExclusion '$atomicRedTeamDir'"
        Reference = "https://success.trendmicro.com/solution/000189676"
    }
    "EDR - Cylance" = @{
        Processes = @("CylanceSvc", "CyOptics", "CylanceProtect", "CylanceUI")
        Command = "No specific command-line arguments for exclusions."
        Reference = "https://support.blackberry.com/community/s/article/68779"
    }
    "EDR - ESET" = @{
        Processes = @("ekrn", "egui", "ekrnEpfw", "ESETService")
        Command = "ecmd.exe add exclusion '$atomicRedTeamDir'"
        Reference = "https://help.eset.com/ees/7/en-US/?cmdline_interface.html"
    }
    "EDR - Kaspersky" = @{
        Processes = @("avp", "kavfs", "avpui", "klnagent")
        Command = "klnagchk add_exclusion --path='$atomicRedTeamDir'"
        Reference = "https://support.kaspersky.com/10536"
    }
    "EDR - Palo Alto Networks Cortex XDR" = @{
        Processes = @("CyveraService", "Traps", "PanService")
        Command = "No direct command-line arguments for exclusions."
        Reference = "https://docs.paloaltonetworks.com/cortex/cortex-xdr/cortex-xdr-prevent-admin/administration/add-exclusions.html"
    }
    "EDR - F-Secure" = @{
        Processes = @("fsorsp", "fshoster", "F-Secure-Security", "fsavd")
        Command = "fsav --exclude '$atomicRedTeamDir'"
        Reference = "https://help.f-secure.com/business/"
    }
    "EDR - Bitdefender" = @{
        Processes = @("vsserv", "bdagent", "vsservp", "bdredline")
        Command = "Navigate to the installation directory (e.g., C:\\Program Files\\Bitdefender\\Endpoint Security) and use the command line interface `product.console` to manage exclusions."
        Reference = "https://www.bitdefender.com/business/enterprise-security.html#solutions"
    }
    "EDR - Tanium" = @{
        Processes = @("taniumclient", "taniumexec", "taniumplugin", "TaniumClient", "TaniumCX", "TaniumDriverSvc")
        Command = "No specific command-line arguments for exclusions."
        Reference = "https://docs.tanium.com/endpointsecurity/endpointsecurity/using_the_tanium_console.html"
    }
    "EDR - BlackBerry Cylance" = @{
        Processes = @("CylanceSvc", "CylanceProtect", "CylanceOptics")
        Command = "No specific command-line arguments for exclusions."
        Reference = "https://support.blackberry.com/community/s/article/68779"
    }
    "EDR - Cisco AMP" = @{
        Processes = @("ciscoamp", "ampdaemon")
        Command = "No specific command-line arguments for exclusions."
        Reference = "https://www.cisco.com/c/en/us/support/security/amp-endpoints/products-installation-guides-list.html"
    }
    "EDR - Cybereason" = @{
        Processes = @("Cybereason", "crdaemon", "crsvr")
        Command = "No specific command-line arguments for exclusions."
        Reference = "https://www.cybereason.com/support"
    }
    "EDR - Morphisec" = @{
        Processes = @("MorphisecService")
        Command = "No specific command-line arguments for exclusions."
        Reference = "https://www.morphisec.com/support"
    }
    "EDR - Cynet" = @{
        Processes = @("CynetService")
        Command = "No specific command-line arguments for exclusions."
        Reference = "https://www.cynet.com/support"
    }
    "EDR - CrowdSec" = @{
        Processes = @("crowdsec-agent")
        Command = "No specific command-line arguments for exclusions."
        Reference = "https://doc.crowdsec.net/docs/"
    }
    "EDR - VMware Carbon Black" = @{
        Processes = @("cbdaemon", "cbstream", "cbcomms")
        Command = "Edit the `cb.conf` file and restart the service."
        Reference = "https://docs.vmware.com/en/VMware-Carbon-Black-EDR/7.8.0/vmw-cb-edr-ug/GUID-3B294CB3-085E-430F-B3F3-DF1F08D11209.html"
    }
    "EDR - Red Canary" = @{
        Processes = @("cfsvcd", "cwp.service", "canary_forwarder")
        Command = "Configuration of exclusions is typically managed through the management console or configuration files."
        Reference = "https://help.redcanary.com/hc/en-us/articles/360053288653-Agent-Sensor-Overview"
    }
    "EDR - Rapid7 InsightIDR" = @{
        Processes = @("InsightAgent", "Rapid7Agent", "rapid7_endpoint_broker", "ir_agent")
        Command = "No specific command-line options for exclusions."
        Reference = "https://docs.rapid7.com/insightidr/"
    }
    "EDR - Check Point Harmony" = @{
        Processes = @("HarmonyEndpoint", "HarmonyAgent")
        Command = "No specific command-line options for exclusions."
        Reference = "https://www.checkpoint.com/support-services/harmony-endpoint/"
    }
    "EDR - Forcepoint" = @{
        Processes = @("fppsvc")
        Command = "No specific command-line options for exclusions."
        Reference = "https://support.forcepoint.com/"
    }
    # Antivirus products
    "AV - Norton" = @{
        Processes = @("Norton360", "NortonSecurity", "NortonAV")
        Command = "No specific command-line options for adding exclusions."
        Reference = "https://support.norton.com/sp/en/us/home/current/info"
    }
    "AV - Bitdefender" = @{
        Processes = @("BitdefenderTS", "BitdefenderIS", "BitdefenderAV")
        Command = "Navigate to the installation directory (e.g., C:\\Program Files\\Bitdefender\\Bitdefender Security) and use the command line interface `product.console` to manage exclusions."
        Reference = "https://www.bitdefender.com/consumer/support/answer/7126/"
    }
    "AV - McAfee" = @{
        Processes = @("mcshield", "masvc", "mfewc")
        Command = "cmdagent.exe /P"
        Reference = "https://docs.mcafee.com/bundle/endpoint-security-10.7.0-client-command-line-reference-guide/page/GUID-6A89B8F3-3C7D-4A84-B16A-C9ACD2C1D7B8.html"
    }
    "AV - Kaspersky" = @{
        Processes = @("avp", "kavfs", "kav")
        Command = "klnagchk add_exclusion --path='$atomicRedTeamDir'"
        Reference = "https://support.kaspersky.com/10536"
    }
    "AV - Avast" = @{
        Processes = @("AvastSvc", "AvastUI")
        Command = "No specific command-line options for adding exclusions."
        Reference = "https://support.avast.com/"
    }
    "AV - AVG" = @{
        Processes = @("avgsvc", "avguix")
        Command = "avgscan --exclude '$atomicRedTeamDir'"
        Reference = "https://support.avg.com/"
    }
    "AV - Trend Micro" = @{
        Processes = @("PccNTMon", "TMBMSRV")
        Command = "TmiCmd.exe -AddExclusion '$atomicRedTeamDir'"
        Reference = "https://success.trendmicro.com/solution/000189676"
    }
    "AV - Sophos" = @{
        Processes = @("savservice", "SAVAdminService")
        Command = "savconfig add Exclusion -p '$atomicRedTeamDir'"
        Reference = "https://docs.sophos.com/esg/enterprise-console/5-12/help/en-us/esg/Enterprise-Console/tasks/UseCommandLineTools.html"
    }
    "AV - F-Secure" = @{
        Processes = @("fsorsp", "fshoster")
        Command = "fsav --exclude '$atomicRedTeamDir'"
        Reference = "https://help.f-secure.com/business/"
    }
    "AV - Webroot" = @{
        Processes = @("WRSA")
        Command = "No specific command-line options for adding exclusions."
        Reference = "https://www.webroot.com/us/en/support"
    }
    "AV - Comodo" = @{
        Processes = @("cmdagent")
        Command = "No specific command-line options for adding exclusions."
        Reference = "https://help.comodo.com/"
    }
    "AV - Panda Security" = @{
        Processes = @("PSANHost", "PSUAService")
        Command = "No specific command-line options for adding exclusions."
        Reference = "https://www.pandasecurity.com/usa/support/"
    }
    "AV - Avira" = @{
        Processes = @("AviraServiceHost")
        Command = "No specific command-line options for adding exclusions."
        Reference = "https://support.avira.com/hc/en-us"
    }
    "AV - BullGuard" = @{
        Processes = @("BullGuardSvc", "BullGuardBhvScanner")
        Command = "No specific command-line options for adding exclusions."
        Reference = "https://www.bullguard.com/support"
    }
    "AV - TotalAV" = @{
        Processes = @("TotalAV")
        Command = "No specific command-line options for adding exclusions."
        Reference = "https://www.totalav.com/support"
    }
    "AV - Intego" = @{
        Processes = @("VirusBarrier", "NetBarrier")
        Command = "No specific command-line options for adding exclusions."
        Reference = "https://www.intego.com/support"
    }
    "AV - Surfshark" = @{
        Processes = @("SurfsharkAV")
        Command = "No specific command-line options for adding exclusions."
        Reference = "https://support.surfshark.com/"
    }
    "AV - G Data" = @{
        Processes = @("AVKWCtl", "GDataAV")
        Command = "No specific command-line options for adding exclusions."
        Reference = "https://www.gdatasoftware.com/support"
    }
    "AV - Dr.Web" = @{
        Processes = @("dwservice", "drwebd")
        Command = "drweb-ctl exclude add '$atomicRedTeamDir'"
        Reference = "https://support.drweb.com/"
    }
    "AV - Adaware" = @{
        Processes = @("AdAwareService")
        Command = "No specific command-line options for adding exclusions."
        Reference = "https://www.adaware.com/support"
    }
    "AV - Quick Heal" = @{
        Processes = @("SCANNER", "QHWatchdog")
        Command = "No specific command-line options for adding exclusions."
        Reference = "https://www.quickheal.com/support"
    }
    "AV - Malwarebytes" = @{
        Processes = @("MBAMService", "MBAM")
        Command = "mbam exclusions add '$atomicRedTeamDir'"
        Reference = "https://support.malwarebytes.com/"
    }
}

# Debugging: Print all running processes
$runningProcesses = Get-Process | Select-Object -Property Name
#Write-Host "Running Processes: $($runningProcesses.Name -join ', ')"

# Check for running processes
$foundProcesses = @()
foreach ($vendor in $processes.Keys) {
    foreach ($process in $processes[$vendor].Processes) {
        if ($runningProcesses.Name -contains $process) {
            $foundProcesses += [PSCustomObject]@{
                Vendor = $vendor
                Process = $process
                Command = $processes[$vendor].Command
                Reference = $processes[$vendor].Reference
            }
        }
    }
}

# Display results if any processes are found
if ($foundProcesses.Count -gt 0) {
    $message = "The following security processes are running on your system:`n`n"
    foreach ($proc in $foundProcesses) {
        $message += "Vendor: $($proc.Vendor)`n"
        $message += "Process: $($proc.Process)`n"
        $message += "Command: $($proc.Command)`n"
        $message += "Reference: $($proc.Reference)`n`n"
    }

    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show($message, "Security Processes Found", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
} else {
    Write-Host "No security processes found."
}

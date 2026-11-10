param(
    [ValidateSet('0', '1', '2', '3', '4', '')]
    [string]$Tier = '',
    [ValidateSet('mullvad', 'warp', '')]
    [string]$Vpn = '',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$RootDir = Split-Path -Parent $PSScriptRoot
$TierNames = @{ 0 = 'Lockdown'; 1 = 'Anonymous'; 2 = 'Hardened'; 3 = 'Private'; 4 = 'Hygiene' }
$Steps = New-Object System.Collections.ArrayList
$Manual = New-Object System.Collections.ArrayList
$script:VpnGated = $false

function Add-Step([string]$Name, [scriptblock]$Action) {
    [void]$Steps.Add([pscustomobject]@{ Name = $Name; Action = $Action })
}

function Add-Manual([string]$Text) { [void]$Manual.Add($Text) }

function Write-Note([string]$Text) { Write-Host "      $Text" }

function Install-App([string]$Id) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget was not found. Install 'App Installer' from the Microsoft Store and run this again."
    }
    winget list --id $Id -e --accept-source-agreements | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Note "$Id is already installed"
        return
    }
    winget install --id $Id -e --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw "winget could not install $Id" }
}

function Get-MullvadCli {
    $cli = Join-Path $env:ProgramFiles 'Mullvad VPN\resources\mullvad.exe'
    if (Test-Path $cli) { return $cli }
    $command = Get-Command mullvad -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    return $null
}

function Test-MullvadConnected {
    $cli = Get-MullvadCli
    if (-not $cli) { return $false }
    return ((& $cli status 2>$null | Out-String) -cmatch 'Connected')
}

function Test-VpnConnected {
    if (Test-MullvadConnected) { return $true }
    $warp = Get-Command warp-cli -ErrorAction SilentlyContinue
    if ($warp) {
        $status = (& $warp.Source status 2>$null | Out-String)
        if ($status -cmatch 'Connected') { return $true }
    }
    return $false
}

function Wait-ForVpn {
    if (Test-VpnConnected) {
        Write-Note 'The VPN is connected.'
        $script:VpnGated = $true
        return
    }
    Write-Host ''
    Write-Note 'OPSEC is paused. Nothing else will be downloaded until a VPN is on,'
    Write-Note 'so your internet provider cannot see what gets installed next.'
    Write-Host ''
    if ($script:Vpn -eq 'warp') {
        Write-Note 'Open Cloudflare WARP from the system tray, accept its terms and'
        Write-Note 'switch it on.'
    }
    else {
        Write-Note 'Open Mullvad VPN, log in and press Connect.'
    }
    Write-Host ''
    while ($true) {
        $answer = Read-Host '      Press Enter once the VPN says Connected, or type q to stop here'
        if ($answer -match '^[qQ]$') {
            Write-Host ''
            Write-Host 'Stopped before installing anything else. Run this again once the'
            Write-Host 'VPN is connected and it will carry on from here.'
            exit 1
        }
        if (Test-VpnConnected) {
            $script:VpnGated = $true
            return
        }
        Write-Note 'The VPN is not connected yet.'
    }
}

function Set-RegistryValue([string]$Path, [string]$Name, [int]$Value) {
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force | Out-Null
}

function Set-FirefoxPolicies {
    $firefox = Join-Path $env:ProgramFiles 'Mozilla Firefox'
    if (-not (Test-Path $firefox)) { throw 'Firefox was not found in Program Files.' }
    $name = if ([int]$script:Tier -le 3) { 'policies-tier3.json' } else { 'policies-tier4.json' }
    $source = Join-Path $RootDir "configs\firefox\$name"
    $destDir = Join-Path $firefox 'distribution'
    $dest = Join-Path $destDir 'policies.json'
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    if ((Test-Path $dest) -and -not (Test-Path "$dest.opsec-backup")) {
        Copy-Item $dest "$dest.opsec-backup"
    }
    Copy-Item $source $dest -Force
    Write-Note 'Restart Firefox to pick up the new settings.'
}

function Test-DiskEncrypted {
    try {
        $volume = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
        return ($volume.ProtectionStatus -eq 'On')
    }
    catch {
        return $null
    }
}

function Set-TelemetryOff {
    Set-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 1
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed' 0
}

function Set-AttackSurfaceRules {
    $rules = @(
        'BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550',
        'D4F940AB-401B-4EFC-AADC-AD5F3C50688A',
        '3B576869-A4EC-4529-8536-B80A7769E899',
        '75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84',
        'D3E037E1-3EB8-44C8-A917-57927947596D',
        '5BEB7EFE-FD9A-4556-801D-275E5FFC04CC',
        '92E97FA1-2EDF-4476-BDD6-9DD0B4DDDC7B',
        '9E6C4E1F-7D60-472F-BA1A-A39EF669E4B2',
        'B2B3F03D-6A65-4F7B-A9C7-1C7EF74A9BA4',
        'C1DB55AB-C21A-4637-BB3F-A12568109D35'
    )
    foreach ($rule in $rules) {
        Add-MpPreference -AttackSurfaceReductionRules_Ids $rule -AttackSurfaceReductionRules_Actions Enabled
    }
    Set-MpPreference -PUAProtection Enabled
    Set-MpPreference -EnableNetworkProtection Enabled
}

function Enable-Sandbox {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName 'Containers-DisposableClientVM' -ErrorAction SilentlyContinue
    if (-not $feature) {
        Write-Note 'Windows Sandbox is not available on this edition of Windows (it needs Pro or higher).'
        throw 'Windows Sandbox unavailable'
    }
    if ($feature.State -eq 'Enabled') {
        Write-Note 'Windows Sandbox is already on'
        return
    }
    Enable-WindowsOptionalFeature -Online -FeatureName 'Containers-DisposableClientVM' -All -NoRestart | Out-Null
}

function Add-VpnFirst {
    if ($script:Vpn -eq 'warp') {
        Add-Step 'Install Cloudflare WARP, the free VPN (first, before anything else)' { Install-App 'Cloudflare.Warp' }
    }
    else {
        Add-Step 'Install Mullvad VPN (first, before anything else)' { Install-App 'MullvadVPN.MullvadVPN' }
    }
    Add-Step 'Wait for you to connect the VPN. Nothing else is downloaded until it is on' { Wait-ForVpn }
}

function Add-Tier4 {
    Add-Step 'Install Firefox' { Install-App 'Mozilla.Firefox' }
    Add-Step 'Set up Firefox: strict tracking protection, HTTPS only, encrypted DNS (Quad9), DuckDuckGo, uBlock Origin and Bitwarden' { Set-FirefoxPolicies }
    Add-Step 'Turn on the Windows firewall and block incoming connections' {
        Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled True -DefaultInboundAction Block
    }
    Add-Step 'Turn on Microsoft Defender real-time protection' {
        Set-MpPreference -DisableRealtimeMonitoring $false
    }
    Add-Manual 'Open Firefox and accept the uBlock Origin and Bitwarden add-ons when it asks.'
    Add-Manual 'Create a Bitwarden vault and turn on two-step login.'
    Add-Manual 'Put an authenticator app (Ente Auth or Aegis) on your phone and use it instead of text-message codes.'
    Add-Manual 'Check Settings > Windows Update and make sure updates are not paused.'
}

function Add-Tier3 {
    if ($script:Vpn -eq 'warp') {
        Add-Manual 'Cloudflare WARP has no kill switch and does not hide your location from websites. Move to Mullvad VPN when you can.'
    }
    else {
        Add-Step 'Turn on the VPN kill switch (lockdown mode) and auto-connect' {
            $cli = Get-MullvadCli
            if (-not $cli) {
                Write-Note 'Mullvad VPN is not installed, so there is nothing to set. If you use another VPN, turn on its kill switch yourself.'
                return
            }
            if (-not ((& $cli status 2>$null | Out-String) -cmatch 'Connected')) {
                Write-Note 'Mullvad is not the VPN that is connected, so lockdown mode was left off.'
                Write-Note 'Turning it on now would cut off your internet. Turn it on in Mullvad''s settings once you use it.'
                return
            }
            & $cli lockdown-mode set on
            & $cli auto-connect set on
        }
    }
    Add-Step 'Install Mullvad Browser for sensitive browsing' { Install-App 'MullvadVPN.MullvadBrowser' }
    Add-Step 'Install Signal' { Install-App 'OpenWhisperSystems.Signal' }
    Add-Step 'Turn off the advertising ID, activity history and optional diagnostics' { Set-TelemetryOff }
    $encrypted = Test-DiskEncrypted
    if ($null -eq $encrypted) {
        Add-Manual 'OPSEC could not tell whether your disk is encrypted, and never encrypts a disk for you. Check Settings > Privacy & security > Device encryption yourself.'
    }
    elseif (-not $encrypted) {
        Add-Manual 'Your disk is NOT encrypted. OPSEC never encrypts a disk for you. If you want it, turn on BitLocker or Device encryption yourself in Settings, and save the recovery key somewhere safe first.'
    }
    Add-Manual 'Accept the Consent-O-Matic add-on in Firefox so cookie banners are rejected for you.'
    Add-Manual 'In Settings > Network & internet > Wi-Fi, turn on Random hardware addresses.'
    Add-Manual 'Sign up for SimpleLogin or Firefox Relay so sign-ups do not get your real email address.'
}

function Add-Tier2 {
    Add-Step 'Turn on Defender attack surface reduction rules, network protection and unwanted-app blocking' { Set-AttackSurfaceRules }
    Add-Step 'Turn on Windows Sandbox for opening untrusted files' { Enable-Sandbox }
    Add-Manual 'Windows can only be partly hardened. Linux is the recommended base for this tier.'
    Add-Manual 'Use a standard (non-administrator) account for daily work.'
    Add-Manual 'Turn on Secure Boot and set a firmware password in your computer''s startup settings.'
    Add-Manual 'Turn on Smart App Control in Windows Security if your PC offers it.'
}

function Add-Tier1 {
    Add-Manual 'Tier 1 runs inside a sealed, Tor-only virtual machine. OPSEC cannot build that VM on Windows yet, so it installs no Tor software on this computer.'
    Add-Manual 'Keep the VPN on, then install VirtualBox and Whonix by following https://www.whonix.org/wiki/Windows. Verify the Whonix download the way that page describes.'
    Add-Manual 'Turn on disk encryption for the Whonix machines in VirtualBox (Settings > General > Disk Encryption) so their contents cannot be read while they are off.'
    Add-Manual 'Do all anonymous activity inside Whonix-Workstation and nothing personal. Never log into personal accounts or reuse usernames there.'
    Add-Manual 'In Tor Browser, click the shield icon and set the security level to Safer. Do not add extensions or change its other settings.'
    Add-Manual 'A VM does not protect against monitoring software installed on this computer itself. Do not use a computer your school or employer manages.'
    Add-Manual 'No tool stops an adversary who can watch both ends of your connection at once. For that level of risk, use Tails (Tier 0).'
    if ($script:Vpn -eq 'warp') {
        Add-Manual 'WARNING: Cloudflare WARP has no kill switch. If it drops while Whonix is running, your network can see that this computer uses Tor. Use Mullvad VPN for this tier.'
    }
}

function Show-Tier0Guide {
    Write-Host @'
Tier 0: Lockdown cannot be applied to the system you are using now.
It means moving to a separate, purpose-built operating system, so
OPSEC gives you a checklist instead of changing this computer.

  1. Choose one:
       Tails     Runs from a USB stick and forgets everything on shutdown.
                 https://tails.net/install/
       Qubes OS  Installed on the computer. Keeps each activity in its
                 own sealed compartment.
                 https://www.qubes-os.org/downloads/
  2. Follow that project's own steps to verify the download before
     installing it. Do not skip the verification.
  3. Keep personal and anonymous activity in separate compartments.
  4. Keep encryption keys and sensitive files on a device that never
     goes online.

Nothing was changed on this computer. To get the strongest setup that
can be applied here, run this again and choose tier 1.
'@
}

if ($Tier -eq '') {
    Write-Host 'Which tier do you want to apply? Tier 0 is the most locked down.'
    Write-Host ''
    Write-Host '  4  Hygiene     Everyday safety. Blocks ads, trackers and scams.'
    Write-Host '  3  Private     Hides your browsing from your internet provider.'
    Write-Host '  2  Hardened    Makes the computer much harder to break into.'
    Write-Host '  1  Anonymous   A sealed virtual machine where everything goes through Tor. Guide only on Windows.'
    Write-Host '  0  Lockdown    A separate operating system. Guide only.'
    Write-Host ''
    while ($true) {
        $answer = Read-Host 'Enter a number from 0 to 4 (or q to quit)'
        if ($answer -match '^[0-4]$') { $Tier = $answer; break }
        if ($answer -match '^[qQ]$') { Write-Host 'Nothing was changed.'; exit 0 }
        Write-Host 'Please type 0, 1, 2, 3 or 4.'
    }
}

$tierNumber = [int]$Tier

if ($tierNumber -eq 0) {
    Show-Tier0Guide
    exit 0
}

if ($tierNumber -le 3) {
    if (Test-MullvadConnected) { $Vpn = 'mullvad' }
    elseif (Test-VpnConnected) { $Vpn = 'warp' }
    if ($Vpn -eq '') {
        Write-Host ''
        Write-Host 'This tier installs a VPN first, so the rest of the downloads are hidden'
        Write-Host 'from your internet provider.'
        Write-Host ''
        Write-Host 'Mullvad VPN is the recommended choice, but it needs a paid account.'
        Write-Host 'If you do not have one, OPSEC uses Cloudflare WARP instead. WARP is'
        Write-Host 'free and hides your activity from your internet provider and Wi-Fi,'
        Write-Host 'but it does not hide your location from websites.'
        Write-Host ''
        while ($true) {
            $answer = Read-Host 'Do you have a Mullvad account? (yes/no, or q to quit)'
            if ($answer -match '^(?i)(y|yes)$') { $Vpn = 'mullvad'; break }
            if ($answer -match '^(?i)(n|no)$') { $Vpn = 'warp'; break }
            if ($answer -match '^[qQ]$') { Write-Host 'Nothing was changed.'; exit 0 }
            Write-Host 'Please type yes or no.'
        }
    }
    Add-VpnFirst
}
foreach ($n in 4, 3, 2, 1) {
    if ($n -ge $tierNumber) { & "Add-Tier$n" }
}

Write-Host ''
Write-Host "Tier ${tierNumber}: $($TierNames[$tierNumber]) on Windows"
Write-Host ''
Write-Host 'OPSEC will make these changes:'
$i = 0
foreach ($step in $Steps) {
    $i++
    Write-Host ('  {0,2}. {1}' -f $i, $step.Name)
}
Write-Host ''
Write-Host 'These need you, so OPSEC will only remind you at the end:'
foreach ($item in $Manual) { Write-Host "   - $item" }
Write-Host ''

if ($DryRun) {
    Write-Host 'Dry run: nothing was changed.'
    exit 0
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'These changes need administrator rights. Right-click PowerShell, choose'
    Write-Host '"Run as administrator", and run this again. Nothing was changed.'
    exit 1
}

Write-Host 'This installs apps and changes system settings. Installing an app'
Write-Host 'accepts its licence terms on your behalf.'
if ($tierNumber -le 3) {
    Write-Host ''
    Write-Host 'The VPN is installed first. OPSEC then waits until it is connected'
    Write-Host 'before downloading anything else. Your internet provider can see'
    Write-Host 'the VPN itself being downloaded, but not what follows.'
    Write-Host ''
}
Write-Host 'Undoing these changes is manual on Windows for now. Files OPSEC'
Write-Host "replaces are kept next to the original with '.opsec-backup' on the end."
Write-Host 'OPSEC keeps no log of this run.'
Write-Host ''
Write-Host 'OPSEC never encrypts your disk or your files. If disk encryption is'
Write-Host 'off, it only tells you, and turning it on is left to you.'
Write-Host ''
$answer = Read-Host "Type 'yes' to apply these changes, or anything else to cancel"
if ($answer -notmatch '^(?i)yes$') {
    Write-Host 'Cancelled. Nothing was changed.'
    exit 0
}

$failed = New-Object System.Collections.ArrayList
$i = 0
foreach ($step in $Steps) {
    $i++
    Write-Host ''
    Write-Host ("[{0}/{1}] {2}" -f $i, $Steps.Count, $step.Name)
    if ($script:VpnGated -and -not (Test-VpnConnected)) {
        Write-Note 'The VPN has disconnected.'
        $script:VpnGated = $false
        Wait-ForVpn
    }
    try {
        & $step.Action
        Write-Host '      done'
    }
    catch {
        Write-Host "      FAILED: $($_.Exception.Message)"
        [void]$failed.Add($step.Name)
    }
}

Write-Host ''
Write-Host ("Finished: {0} of {1} steps succeeded." -f ($Steps.Count - $failed.Count), $Steps.Count)
if ($failed.Count -gt 0) {
    Write-Host ''
    Write-Host 'These steps did not finish. Scroll up to see why:'
    foreach ($name in $failed) { Write-Host "   - $name" }
}
Write-Host ''
Write-Host 'Still to do yourself:'
foreach ($item in $Manual) { Write-Host "   - $item" }
Write-Host ''
Write-Host 'Restart the computer to make sure every change takes effect.'
if ($failed.Count -gt 0) { exit 1 }

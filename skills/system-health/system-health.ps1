# État de santé d'un poste Windows : charge, mémoire, disques, batterie, processus gourmands.
# Lecture seule : ne modifie aucun réglage et ne termine aucun processus.
# Usage : powershell -NoProfile -File system-health.ps1   (ou pwsh)

$ErrorActionPreference = 'SilentlyContinue'
$cores = [Environment]::ProcessorCount
$os = Get-CimInstance Win32_OperatingSystem
function Gb($bytes) { [Math]::Round($bytes / 1GB, 1) }

"# Santé du poste - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"

"`n## Système"
$uptime = (Get-Date) - $os.LastBootUpTime
"$($os.Caption) ($($os.Version)) - allumé depuis $([int]$uptime.TotalDays) j $($uptime.Hours) h"
$scheme = (powercfg /getactivescheme) -replace '.*\((.*)\).*', '$1'
if ($scheme) { "Mode d'alimentation : $scheme" }

"`n## Processeur"
$cpu = Get-CimInstance Win32_Processor
$load = [int](($cpu | Measure-Object LoadPercentage -Average).Average)
"$(($cpu | Select-Object -First 1).Name.Trim()) - $cores coeurs logiques - charge instantanée : $load %"

"`n## Mémoire"
$total = $os.TotalVisibleMemorySize * 1KB
$free = $os.FreePhysicalMemory * 1KB
"RAM : $(Gb ($total - $free)) / $(Gb $total) Go utilisés ($([int](100 * ($total - $free) / $total)) %)"
$commitTotal = $os.TotalVirtualMemorySize * 1KB
$commitFree = $os.FreeVirtualMemory * 1KB
"Mémoire engagée (RAM + fichier d'échange) : $(Gb ($commitTotal - $commitFree)) / $(Gb $commitTotal) Go ($([int](100 * ($commitTotal - $commitFree) / $commitTotal)) %)"

"`n## Disques"
Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
    "$($_.DeviceID) $(Gb $_.FreeSpace) Go libres sur $(Gb $_.Size) Go ($([int](100 * $_.FreeSpace / $_.Size)) % libres)"
}

"`n## Batterie"
$battery = Get-CimInstance Win32_Battery
if (-not $battery) {
    "Aucune batterie détectée (poste fixe ou batterie non exposée)."
} else {
    $status = @{ 1 = 'sur batterie'; 2 = 'sur secteur'; 3 = 'chargée'; 4 = 'faible'; 5 = 'critique'; 6 = 'en charge'; 7 = 'en charge (haute)'; 8 = 'en charge (faible)'; 9 = 'en charge (critique)'; 11 = 'partiellement chargée' }
    foreach ($b in $battery) { "Charge : $($b.EstimatedChargeRemaining) % - $($status[[int]$b.BatteryStatus])" }
    $design = (Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData | Select-Object -First 1).DesignedCapacity
    $full = (Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity | Select-Object -First 1).FullChargedCapacity
    $cycles = (Get-CimInstance -Namespace root\wmi -ClassName BatteryCycleCount | Select-Object -First 1).CycleCount
    if ($design -and $full) {
        "Capacité actuelle : $([int](100 * $full / $design)) % de la capacité d'origine ($full / $design mWh)"
    } else {
        "Capacité d'origine non lisible sans droits administrateur : powercfg /batteryreport produit un rapport complet."
    }
    if ($cycles) { "Cycles de charge : $cycles" }
}

"`n## Processus les plus gourmands en mémoire"
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 | ForEach-Object {
    "{0,-32} {1,8} Mo" -f $_.ProcessName, [int]($_.WorkingSet64 / 1MB)
}

"`n## Processus les plus gourmands en processeur (instantané)"
Get-CimInstance Win32_PerfFormattedData_PerfProc_Process |
    Where-Object { $_.Name -notin '_Total', 'Idle' } |
    Sort-Object PercentProcessorTime -Descending | Select-Object -First 10 | ForEach-Object {
        "{0,-32} {1,5} %" -f ($_.Name -replace '#\d+$', ''), [int]($_.PercentProcessorTime / $cores)
    }

"`n## Outils de développement et navigateurs (mémoire cumulée)"
$groups = [ordered]@{
    'Node.js (Claude Code, serveurs MCP, outils JS)' = 'node'
    'Claude'                                         = 'claude'
    'VS Code'                                        = 'Code'
    'Navigateurs (Chrome, Edge, Firefox)'            = 'chrome|msedge|firefox'
    'Docker / WSL'                                   = 'vmmem|vmmemWSL|com\.docker.*|Docker Desktop'
    'Java / JVM'                                     = 'java|javaw'
    'Python'                                         = 'python|pythonw'
}
$all = Get-Process
foreach ($name in $groups.Keys) {
    $procs = @($all | Where-Object { $_.ProcessName -match "^($($groups[$name]))$" })
    if ($procs.Count) {
        "{0,-48} {1,3} processus {2,8} Mo" -f $name, $procs.Count, [int](($procs | Measure-Object WorkingSet64 -Sum).Sum / 1MB)
    }
}

"`n## Démarrage"
"Programmes lancés au démarrage : $(@(Get-CimInstance Win32_StartupCommand).Count)"

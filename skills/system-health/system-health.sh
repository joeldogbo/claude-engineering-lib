#!/usr/bin/env bash
# État de santé d'un poste macOS ou Linux : charge, mémoire, disque, batterie, processus gourmands.
# Lecture seule : ne modifie aucun réglage et ne termine aucun processus.
# Sous Windows, utiliser system-health.ps1.
# Usage : bash system-health.sh

set -u
OS="$(uname -s)"
case "$OS" in
  Darwin|Linux) ;;
  *) echo "Système $OS non pris en charge par ce script : sous Windows, utiliser system-health.ps1."; exit 1 ;;
esac

echo "# Santé du poste - $(date '+%Y-%m-%d %H:%M')"

echo
echo "## Système"
if [[ "$OS" == "Darwin" ]]; then
  echo "macOS $(sw_vers -productVersion 2>/dev/null) - $(uptime | sed -E 's/.*up ([^,]*),.*/allumé depuis \1/')"
else
  name="$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME")"
  echo "${name:-Linux} ($(uname -r)) - $(uptime -p 2>/dev/null || uptime)"
fi

echo
echo "## Processeur"
if [[ "$OS" == "Darwin" ]]; then
  cores="$(sysctl -n hw.logicalcpu)"
  model="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || sysctl -n hw.model)"
  load="$(sysctl -n vm.loadavg | awk '{print $2, $3, $4}')"
else
  cores="$(getconf _NPROCESSORS_ONLN)"
  model="$(awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo)"
  load="$(cut -d' ' -f1-3 /proc/loadavg)"
fi
echo "${model:-processeur inconnu} - $cores coeurs logiques"
echo "Charge moyenne 1 / 5 / 15 min : $load (saturé au-delà de $cores)"

echo
echo "## Mémoire"
if [[ "$OS" == "Darwin" ]]; then
  total=$(( $(sysctl -n hw.memsize) / 1048576 ))
  page=$(sysctl -n hw.pagesize)
  # Mémoire réellement disponible : pages libres + inactives + purgeables.
  avail=$(vm_stat | awk -v p="$page" '/Pages free|Pages inactive|Pages purgeable/ {gsub("\\.","",$NF); s+=$NF} END {print int(s*p/1048576)}')
  echo "RAM : $(( total - avail )) / $total Mo utilisés ($(( 100 * (total - avail) / total )) %)"
  swap="$(sysctl -n vm.swapusage 2>/dev/null)"
  [[ -n "$swap" ]] && echo "Swap : $swap"
  pressure="$(memory_pressure 2>/dev/null | awk -F': ' '/free percentage/ {print $2}')"
  [[ -n "$pressure" ]] && echo "Mémoire libre selon macOS : $pressure"
else
  total=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
  avail=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
  echo "RAM : $(( total - avail )) / $total Mo utilisés ($(( 100 * (total - avail) / total )) %)"
  awk '/SwapTotal/ {t=$2} /SwapFree/ {f=$2} END {if (t>0) printf "Swap : %d / %d Mo utilisés\n", (t-f)/1024, t/1024; else print "Swap : aucun"}' /proc/meminfo
fi

echo
echo "## Disques"
df -h / "$HOME" 2>/dev/null | awk 'NR==1 || !seen[$1]++'

echo
echo "## Batterie"
if [[ "$OS" == "Darwin" ]]; then
  if pmset -g batt | grep -q 'InternalBattery'; then
    pmset -g batt | sed -n '2p' | sed -E 's/^.*\t//'
    system_profiler SPPowerDataType 2>/dev/null | grep -E 'Cycle Count|Condition|Maximum Capacity' | sed -E 's/^ +//'
  else
    echo "Aucune batterie détectée (poste fixe)."
  fi
else
  found=0
  for bat in /sys/class/power_supply/BAT*; do
    [[ -d "$bat" ]] || continue
    found=1
    echo "$(basename "$bat") : $(cat "$bat/capacity" 2>/dev/null) % - $(cat "$bat/status" 2>/dev/null)"
    full="$(cat "$bat/energy_full" 2>/dev/null || cat "$bat/charge_full" 2>/dev/null)"
    design="$(cat "$bat/energy_full_design" 2>/dev/null || cat "$bat/charge_full_design" 2>/dev/null)"
    if [[ -n "$full" && -n "$design" && "$design" -gt 0 ]]; then
      echo "Capacité actuelle : $(( 100 * full / design )) % de la capacité d'origine"
    fi
    cycles="$(cat "$bat/cycle_count" 2>/dev/null)"
    [[ -n "$cycles" && "$cycles" != "0" ]] && echo "Cycles de charge : $cycles"
  done
  [[ $found -eq 0 ]] && echo "Aucune batterie détectée (poste fixe ou machine virtuelle)."
fi

echo
echo "## Processus les plus gourmands en mémoire"
ps -eo rss=,comm= | sort -nr | head -10 | awk '{rss=$1; $1=""; sub(/^ /,""); n=split($0,p,"/"); printf "%-32s %8d Mo\n", p[n], rss/1024}'

echo
echo "## Processus les plus gourmands en processeur"
ps -eo pcpu=,comm= | sort -nr | head -10 | awk '{c=$1; $1=""; sub(/^ /,""); n=split($0,p,"/"); printf "%-32s %6.1f %%\n", p[n], c}'

echo
echo "## Outils de développement et navigateurs (mémoire cumulée)"
ps -eo rss=,comm= | awk '
  { rss=$1; $1=""; sub(/^ /,""); n=split($0,p,"/"); name=tolower(p[n]) }
  name ~ /^node$/                          { g="Node.js (Claude Code, serveurs MCP, outils JS)" }
  name ~ /^claude/                         { g="Claude" }
  name ~ /^code( helper.*)?$|electron/     { g="VS Code / Electron" }
  name ~ /chrome|chromium|firefox|safari|msedge/ { g="Navigateurs" }
  name ~ /docker|qemu|virtualization/      { g="Docker / machines virtuelles" }
  name ~ /^java$/                          { g="Java / JVM" }
  name ~ /^python/                         { g="Python" }
  g != "" { mem[g]+=rss; cnt[g]++; g="" }
  END { for (k in mem) printf "%-48s %3d processus %8d Mo\n", k, cnt[k], mem[k]/1024 }'

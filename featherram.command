#!/bin/zsh

app_name="FeatherRAM"
script_dir="${0:A:h}"
version_file="$script_dir/VERSION"
if [[ ! -f "$version_file" ]]; then
  print -u2 "FeatherRAM could not start: VERSION is missing. Reinstall the complete app."
  exit 1
fi
version="$(<"$version_file")"
author="Tarang Sanghi"
homepage="https://github.com/taranggsannghi/featherram"
refresh_seconds="${FEATHERRAM_REFRESH_SECONDS:-${RAM_OPTIMIZER_REFRESH_SECONDS:-5}}"
limit="${FEATHERRAM_LIMIT:-${RAM_OPTIMIZER_LIMIT:-15}}"
monitoring_settings_file="${FEATHERRAM_SETTINGS_FILE:-$HOME/Library/Application Support/FeatherRAM/automatic-monitoring}"
auto_refresh=1
alerts_enabled=1
pressure_streak=0
last_alert_at=0
last_alert_level=0
pressure_level=0
headroom_percent=""
vm_snapshot=""
action_message=""

case "$refresh_seconds" in
  ''|*[!0-9]*) refresh_seconds=5 ;;
esac
if (( refresh_seconds < 1 || refresh_seconds > 3600 )); then
  refresh_seconds=5
fi

case "$limit" in
  ''|*[!0-9]*) limit=15 ;;
esac
if (( limit < 1 || limit > 30 )); then
  limit=15
fi

case "${FEATHERRAM_ALERTS:-1}" in
  0|off|false) alerts_enabled=0 ;;
esac

if [[ -r "$monitoring_settings_file" ]]; then
  case "$(<"$monitoring_settings_file")" in
    0|off) auto_refresh=0 ;;
    1|on) auto_refresh=1 ;;
  esac
fi

save_automatic_monitoring() {
  local settings_dir="${monitoring_settings_file:h}"
  local temp_file="$settings_dir/.automatic-monitoring.$$"

  mkdir -p "$settings_dir" || return 1
  if ! (umask 077; printf '%s\n' "$auto_refresh" > "$temp_file"); then
    rm -f "$temp_file"
    return 1
  fi
  if ! mv -f "$temp_file" "$monitoring_settings_file"; then
    rm -f "$temp_file"
    return 1
  fi
}

print_banner() {
  printf "%s v%s\n" "$app_name" "$version"
}

print_about() {
  echo "$app_name v$version"
  echo "Created by $author"
  echo "Monitor macOS memory pressure, browse process groups, and get optional alerts."
}

print_help() {
  print_about
  echo
  echo "Usage:"
  echo "  ./featherram.command             Open the live dashboard"
  echo "  ./featherram.command --once      Show one snapshot"
  echo "  ./featherram.command --version   Show the app version"
  echo "  ./featherram.command --help      Show this help"
  echo
  echo "Settings:"
  echo "  FEATHERRAM_REFRESH_SECONDS=5     Auto-refresh interval (1-3600 seconds)"
  echo "  FEATHERRAM_LIMIT=15             Groups shown on the dashboard (1-30)"
  echo "  FEATHERRAM_ALERTS=1             Start with pressure alerts on (0 = off)"
  echo "  FEATHERRAM_SETTINGS_FILE=path   Alternate saved auto-refresh setting"
  echo
  echo "Auto-refresh can be switched on or off in the app; this choice is saved."
  echo "Pressure alerts notify after 3 warning or critical scans while auto-refresh is on."
  echo "Alerts never clear cache. Cache clearing is a separate manual action."
  echo
  echo "Legacy settings: RAM_OPTIMIZER_REFRESH_SECONDS and RAM_OPTIMIZER_LIMIT."
}

case "${1:-}" in
  --version|-v)
    echo "$app_name v$version"
    exit 0
    ;;
  --help|-h)
    print_help
    exit 0
    ;;
esac

memory_snapshot() {
  if [[ -z "$vm_snapshot" ]]; then
    echo "Memory breakdown unavailable. Refresh to retry."
    return
  fi

  printf "%s\n" "$vm_snapshot" | awk '
    BEGIN { page_size = 4096 }
    /^Mach Virtual Memory Statistics:/ {
      if (match($0, /page size of [0-9]+ bytes/)) {
        page_size_text = substr($0, RSTART, RLENGTH)
        gsub(/[^0-9]/, "", page_size_text)
        page_size = page_size_text
      }
    }
    /Pages free:/ { free = $3 }
    /Pages active:/ { active = $3 }
    /Pages inactive:/ { inactive = $3 }
    /Pages speculative:/ { speculative = $3 }
    /Pages wired down:/ { wired = $4 }
    /Pages occupied by compressor:/ { compressed = $5 }
    END {
      gsub(/\./, "", free)
      gsub(/\./, "", active)
      gsub(/\./, "", inactive)
      gsub(/\./, "", speculative)
      gsub(/\./, "", wired)
      gsub(/\./, "", compressed)

      printf "%-13s %6.2f GB\n", "Free:", free * page_size / 1024 / 1024 / 1024
      printf "%-13s %6.2f GB\n", "Standby:", speculative * page_size / 1024 / 1024 / 1024
      printf "%-13s %6.2f GB\n", "Inactive:", inactive * page_size / 1024 / 1024 / 1024
      printf "%-13s %6.2f GB\n", "Compressed:", compressed * page_size / 1024 / 1024 / 1024
      printf "%-13s %6.2f GB\n", "Wired:", wired * page_size / 1024 / 1024 / 1024
      printf "%-13s %6.2f GB\n", "Active:", active * page_size / 1024 / 1024 / 1024
    }
  '
}

read_memory_metrics() {
  vm_snapshot="$(vm_stat 2>/dev/null)"
  pressure_level="$(sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null)"
  case "$pressure_level" in
    1|2|4) ;;
    *) pressure_level=0 ;;
  esac

  headroom_percent="$(memory_pressure -Q 2>/dev/null | awk '/System-wide memory free percentage:/ { gsub(/%/, "", $NF); print $NF; exit }')"
  case "$headroom_percent" in
    ''|*[!0-9]*) headroom_percent="" ;;
  esac
  if [[ -n "$headroom_percent" ]] && (( headroom_percent > 100 )); then
    headroom_percent=""
  fi
}

pressure_name() {
  case "$pressure_level" in
    1) echo "Normal" ;;
    2) echo "Warning" ;;
    4) echo "Critical" ;;
    *) echo "Unavailable" ;;
  esac
}

pressure_advice() {
  case "$pressure_level" in
    1) echo "No action needed." ;;
    2) echo "Pressure is elevated. Check Activity Monitor if apps feel slow." ;;
    4) echo "Save your work. Check large apps in Activity Monitor." ;;
    *) echo "Could not read macOS memory pressure. Refresh to retry." ;;
  esac
}

headroom_bar() {
  if [[ -z "$headroom_percent" ]]; then
    echo "Unavailable"
    return
  fi

  local width=24
  local filled=$(( (headroom_percent * width + 50) / 100 ))
  local index=0
  local bar=""

  for (( index = 0; index < width; index++ )); do
    if (( index < filled )); then
      bar+="#"
    else
      bar+="-"
    fi
  done

  printf "[%s] %s%%\n" "$bar" "$headroom_percent"
}

alerts_status() {
  if (( ! alerts_enabled )); then
    echo "off; this session"
  elif (( ! auto_refresh )); then
    echo "on, paused; this session"
  else
    echo "on; this session"
  fi
}

dashboard_alerts_status() {
  if (( ! alerts_enabled )); then
    echo "Off"
  elif (( ! auto_refresh )); then
    echo "Paused"
  else
    echo "On"
  fi
}

maybe_notify() {
  if (( ! auto_refresh || ! alerts_enabled )); then
    return
  fi

  if (( pressure_level != 2 && pressure_level != 4 )); then
    pressure_streak=0
    return
  fi

  (( pressure_streak++ ))
  if (( pressure_streak < 3 )); then
    return
  fi

  local now="$(date +%s)"
  if (( last_alert_at > 0 && now - last_alert_at < 1800 && pressure_level <= last_alert_level )); then
    return
  fi

  local message="Memory pressure has stayed elevated. Check large apps in Activity Monitor."
  if (( pressure_level == 4 )); then
    message="Memory pressure is critical. Save your work and check Activity Monitor."
  fi

  if osascript -e "display notification \"$message\" with title \"FeatherRAM\"" >/dev/null 2>&1; then
    last_alert_at="$now"
    last_alert_level="$pressure_level"
  fi
}

auto_refresh_status() {
  if [[ "$auto_refresh" == "1" ]]; then
    echo "on"
  else
    echo "off"
  fi
}

dashboard_auto_refresh_status() {
  if [[ "$auto_refresh" == "1" ]]; then
    echo "On (${refresh_seconds}s)"
  else
    echo "Off"
  fi
}

apply_refresh_seconds() {
  local next_seconds="$1"

  case "$next_seconds" in
    ''|*[!0-9]*)
      return 1
      ;;
  esac

  if (( next_seconds < 1 || next_seconds > 3600 )); then
    return 1
  fi

  refresh_seconds="$next_seconds"
  auto_refresh=1
  if ! save_automatic_monitoring; then
    print -u2 "Could not save auto-refresh. This choice applies only until you quit."
  fi
  return 0
}

prompt_custom_refresh_seconds() {
  local custom_seconds=""

  while true; do
    read -r "?Seconds (1-3600; Return to go back): " custom_seconds

    if [[ -z "$custom_seconds" ]]; then
      return 1
    fi

    case "$custom_seconds" in
      *[!0-9]*)
        echo "Enter a whole number of seconds."
        continue
        ;;
    esac

    if (( custom_seconds < 1 || custom_seconds > 3600 )); then
      echo "Choose 1-3600 seconds."
      continue
    fi

    apply_refresh_seconds "$custom_seconds"
    echo "Auto-refresh set to every ${refresh_seconds}s."
    return 0
  done
}

group_rows=""
group_process_count=0
group_count=0
group_snapshot_time=""
group_page=1
group_page_size=20

collect_memory_groups() {
  local snapshot

  snapshot="$(ps -axo rss=,comm= 2>/dev/null)"
  group_rows=""
  group_process_count=0
  group_count=0
  group_snapshot_time="$(date '+%H:%M:%S')"
  if [[ -z "$snapshot" ]]; then
    return 1
  fi

  group_process_count="$(printf '%s\n' "$snapshot" | awk 'NF { count++ } END { print count + 0 }')"
  group_rows="$(
    printf '%s\n' "$snapshot" | awk '
    function basename(path) {
      sub(/^.*\//, "", path)
      return path
    }

    function appname(path, name, bundle) {
      name = basename(path)

      if (match(path, /[^\/]+\.app\//)) {
        bundle = substr(path, RSTART, RLENGTH - 1)
        sub(/\.app$/, "", bundle)
        return bundle
      }

      sub(/ Helper.*/, "", name)
      sub(/ \(Renderer\).*/, "", name)
      sub(/ \(GPU\).*/, "", name)
      sub(/ \(Plugin\).*/, "", name)
      sub(/ \(Extension\).*/, "", name)

      return name
    }

    NF {
      if ($1 ~ /^[0-9]+$/) {
        rss = $1
        sub(/^[[:space:]]*[0-9]+[[:space:]]*/, "")
        app = appname($0)
        if (app == "") app = "(unnamed process)"
      } else {
        rss = 0
        app = "(unparsed process entry)"
      }
      mem[app] += rss
      processes[app]++
    }

    END {
      for (app in mem) {
        printf "%.0f\t%d\t%s\n", mem[app], processes[app], app
      }
    }
  ' | sort -nr -k1,1 | awk -F '\t' '
    {
      rss = $1
      processes = $2
      sub(/^[^\t]*\t[^\t]*\t/, "")
      megabytes = rss / 1024
      if (megabytes >= 1024) {
        printf "%9.2f GB  %5d  %s\n", megabytes / 1024, processes, $0
      } else {
        printf "%9.1f MB  %5d  %s\n", megabytes, processes, $0
      }
    }
  '
  )"

  if [[ -n "$group_rows" ]]; then
    group_count="$(printf '%s\n' "$group_rows" | wc -l | tr -d '[:space:]')"
    return 0
  fi
  return 1
}

top_memory_apps() {
  local mode="$1"
  local shown_count

  if collect_memory_groups; then
    shown_count=$(( group_count < limit ? group_count : limit ))
    printf "Top %d of %d process groups (%d processes)\n" "$shown_count" "$group_count" "$group_process_count"
    echo "     Memory  Processes  Group"
    printf '%s\n' "$group_rows" | head -n "$limit"
    if [[ "$mode" == "interactive" ]]; then
      echo "Choose 3 to browse all groups."
    fi
    echo "Memory estimates may count shared memory more than once."
  else
    echo "Process list unavailable. Refresh to retry, or open Activity Monitor."
  fi
}

show_all_groups() {
  local page_count first_row last_row

  printf '\033[H\033[2J'
  print_banner
  echo
  if (( group_count == 0 )); then
    echo "Process list unavailable. Press r to rescan or q to return."
    return
  fi

  page_count=$(( (group_count + group_page_size - 1) / group_page_size ))
  (( group_page > page_count )) && group_page=$page_count
  first_row=$(( (group_page - 1) * group_page_size + 1 ))
  last_row=$(( first_row + group_page_size - 1 ))
  (( last_row > group_count )) && last_row=$group_count

  printf "All %d process groups (%d processes)\n" "$group_count" "$group_process_count"
  printf "Snapshot %s | Page %d of %d | Groups %d-%d\n" "$group_snapshot_time" "$group_page" "$page_count" "$first_row" "$last_row"
  echo "This list updates only when you rescan."
  echo
  echo "         Memory  Processes  Group"
  printf '%s\n' "$group_rows" | awk -v first="$first_row" -v last="$last_row" 'NR >= first && NR <= last { printf "%4d  %s\n", NR, $0 }'
  echo
  echo "Includes apps and macOS tasks. Memory estimates may count shared memory more than once."
}

clear_file_cache_manual() {
  local password="" key=""

  if ! command -v purge >/dev/null 2>&1; then
    action_message="INCOMPATIBLE MAC."
    return 1
  fi

  printf "Mac password (hidden; Esc returns to dashboard): "
  while true; do
    if ! read -rsk1 key; then
      printf '\n'
      password=""
      action_message="CANCELLED."
      return 2
    fi

    case "$key" in
      $'\e')
        printf '\n'
        password=""
        action_message="CANCELLED."
        return 2
        ;;
      $'\r'|$'\n'|'')
        printf '\n'
        break
        ;;
      $'\x7f'|$'\b')
        password="${password%?}"
        ;;
      *)
        password+="$key"
        ;;
    esac
  done

  if [[ -z "$password" ]]; then
    action_message="CANCELLED."
    return 2
  fi

  echo "OPTIMIZING..."
  if printf '%s\n' "$password" | sudo -S -k -p '' purge; then
    password=""
    action_message="DONE."
    return 0
  fi

  password=""
  action_message="FAILED - Check your password or permissions."
  return 1
}

show_dashboard() {
  local mode="$1"
  read_memory_metrics

  if [[ "$mode" == "interactive" ]]; then
    maybe_notify
    printf '\033[H\033[2J'
  fi

  print_banner
  printf "Updated %s | Auto-refresh: %s | Pressure alerts: %s\n" "$(date '+%H:%M:%S')" "$(dashboard_auto_refresh_status)" "$(dashboard_alerts_status)"
  if [[ -n "$action_message" ]]; then
    printf '%s\n' "$action_message"
    action_message=""
  fi
  echo
  printf "Memory pressure: %s\n" "$(pressure_name)"
  pressure_advice
  printf "Memory headroom: "
  if [[ -z "$headroom_percent" ]]; then
    echo "Unavailable"
  else
    headroom_bar
  fi
  echo
  echo "Memory breakdown"
  memory_snapshot
  echo
  top_memory_apps "$mode"
}

if [[ "$1" == "--once" ]]; then
  show_dashboard once
  exit 0
fi

if [[ ! -t 0 ]]; then
  show_dashboard once
  exit 0
fi

menu_state="main"

while true; do
  case "$menu_state" in
    main)
      show_dashboard interactive
      echo
      echo "Actions"
      echo "1. Refresh"
      echo "2. Optimise RAM"
      echo "3. Browse all $group_count groups"
      echo "4. Open Activity Monitor"
      echo "5. Auto-refresh ($(auto_refresh_status))"
      echo "6. Auto-refresh interval (${refresh_seconds}s)"
      echo "7. Pressure alerts ($(alerts_status))"
      echo "   Notifies after 3 warning or critical scans; never clears cache."
      echo "8. Quit"
      echo
      choice=""
      if [[ "$auto_refresh" == "1" ]]; then
        if ! read -t "$refresh_seconds" "?Choose 1-8, or wait ${refresh_seconds}s to refresh: " choice; then
          continue
        fi
      else
        read -r "?Choose 1-8: " choice
      fi

      case "$choice" in
        1)
          ;;
        2)
          echo
          clear_file_cache_manual
          ;;
        3)
          group_page=1
          menu_state="groups"
          ;;
        4)
          open -a "Activity Monitor"
          ;;
        5)
          if (( auto_refresh )); then
            auto_refresh=0
            pressure_streak=0
            action_message="Auto-refresh off. Pressure alerts paused."
          else
            auto_refresh=1
            action_message="Auto-refresh on, every ${refresh_seconds}s."
          fi
          if ! save_automatic_monitoring; then
            echo "Could not save auto-refresh. This choice applies only until you quit."
            read -r "?Press Return to continue..."
          fi
          ;;
        6)
          menu_state="auto_refresh"
          ;;
        7)
          if (( alerts_enabled )); then
            alerts_enabled=0
            action_message="Pressure alerts off for this session."
          else
            alerts_enabled=1
            if (( auto_refresh )); then
              action_message="Pressure alerts on for this session."
            else
              action_message="Pressure alerts on, paused until auto-refresh is on."
            fi
          fi
          ;;
        8)
          exit 0
          ;;
        *)
          echo "Choose a number from 1 to 8."
          sleep 1
          ;;
      esac
      ;;
    groups)
      show_all_groups
      echo
      echo "n Next page   p Previous page   r Rescan   q Dashboard"
      echo "Or enter a page number."
      choice=""
      read -r "?Choose n, p, r, q, or page: " choice

      case "$choice" in
        n|N)
          if (( group_page * group_page_size < group_count )); then
            (( group_page++ ))
          fi
          ;;
        p|P)
          if (( group_page > 1 )); then
            (( group_page-- ))
          fi
          ;;
        r|R)
          collect_memory_groups
          group_page=1
          ;;
        q|Q)
          menu_state="main"
          ;;
        ''|*[!0-9]*)
          echo "Choose n, p, r, q, or a page number."
          sleep 1
          ;;
        *)
          page_count=$(( (group_count + group_page_size - 1) / group_page_size ))
          if (( choice >= 1 && choice <= page_count )); then
            group_page=$choice
          else
            printf "Choose a page from 1 to %d.\n" "$page_count"
            sleep 1
          fi
          ;;
      esac
      ;;
    auto_refresh)
      show_dashboard interactive
      echo
      echo "Auto-refresh interval"
      echo "Choose a preset, enter a custom interval, or turn auto-refresh off."
      echo "1. Turn off"
      if [[ "$refresh_seconds" == "2" ]]; then
        echo "2. 2 seconds (current)"
      else
        echo "2. 2 seconds"
      fi
      if [[ "$refresh_seconds" == "3" ]]; then
        echo "3. 3 seconds (current)"
      else
        echo "3. 3 seconds"
      fi
      if [[ "$refresh_seconds" == "5" ]]; then
        echo "4. 5 seconds (recommended, current)"
      else
        echo "4. 5 seconds (recommended)"
      fi
      if [[ "$refresh_seconds" == "10" ]]; then
        echo "5. 10 seconds (current)"
      else
        echo "5. 10 seconds"
      fi
      echo "6. Custom interval"
      echo "7. Back"
      echo
      choice=""
      read -r "?Choose 1-7: " choice

      case "$choice" in
        1)
          auto_refresh=0
          pressure_streak=0
          if ! save_automatic_monitoring; then
            echo "Could not save auto-refresh. This choice applies only until you quit."
          fi
          echo "Auto-refresh off. Pressure alerts paused."
          read -r "?Press Return to continue..."
          menu_state="main"
          ;;
        2)
          apply_refresh_seconds 2
          echo "Auto-refresh set to every 2 seconds."
          read -r "?Press Return to continue..."
          menu_state="main"
          ;;
        3)
          apply_refresh_seconds 3
          echo "Auto-refresh set to every 3 seconds."
          read -r "?Press Return to continue..."
          menu_state="main"
          ;;
        4)
          apply_refresh_seconds 5
          echo "Auto-refresh set to every 5 seconds."
          read -r "?Press Return to continue..."
          menu_state="main"
          ;;
        5)
          apply_refresh_seconds 10
          echo "Auto-refresh set to every 10 seconds."
          read -r "?Press Return to continue..."
          menu_state="main"
          ;;
        6)
          if prompt_custom_refresh_seconds; then
            read -r "?Press Return to continue..."
          fi
          menu_state="main"
          ;;
        7)
          menu_state="main"
          ;;
        *)
          echo "Choose a number from 1 to 7."
          sleep 1
          ;;
      esac
      ;;
  esac
done

# Stop BOINC while aider runs; restart on exit only if it was running before
aider-boinc() {
  local restart_boinc=0
  if systemctl is-active --quiet boinc 2>/dev/null; then
    restart_boinc=1
    sudo systemctl stop boinc
  fi
  trap '[[ $restart_boinc -eq 1 ]] && sudo systemctl start boinc' EXIT
  command aider "$@"
}

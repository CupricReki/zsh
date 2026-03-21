# Docker Compose - env-sourcing wrapper
# Sources global.env, host-specific env, and /opt/secrets/*.env before running
# docker compose, ensuring all variables are available for YAML interpolation
# (e.g. ${DOMAIN} in labels, ${RADARR_API_KEY} in homepage widget labels).
# All convenience aliases below chain through dc() and inherit this behaviour.
# Note: command_exists is defined in zshenv
unalias dc 2>/dev/null
dc() {
  set -a
  [[ -f /opt/environment/env/global.env ]] && source /opt/environment/env/global.env
  [[ -f /opt/environment/env/hosts/$(hostname -s).env ]] && source /opt/environment/env/hosts/$(hostname -s).env
  for f in /opt/secrets/*.env; do
    [[ -f "$f" ]] && source "$f"
  done
  set +a
  if command_exists docker-compose; then
    command docker-compose "$@"
  elif command_exists docker && docker compose version &>/dev/null; then
    command docker compose "$@"
  else
    echo "dc: docker compose not found" >&2
    return 1
  fi
}

# Docker Compose convenience aliases
alias dcd='dc down'
alias dcl='dc logs -f'
alias dcu='dc up'
alias dcud='dc up -d'
alias dcudl='dcud && dcl'
alias dcr='dcd && dcud'
alias dcur='dcd && dc pull && dcud'
alias dce='docker exec -it ${PWD##*/} /bin/bash'
alias dcesh='docker exec -it ${PWD##*/} /bin/sh'

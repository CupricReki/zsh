# Docker Compose alias - supports both standalone and docker compose
if command -v docker-compose &> /dev/null; then
  alias dc=docker-compose
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
  alias dc="docker compose"
fi

# Docker Compose convenience aliases
alias dcd='dc down'
alias dcl='dc logs -f'
alias dcu='dc up'
alias dcud='dc up -d'
alias dcudl='dcud && dcl'
alias dcr='dcd && dcud'
alias dcur='dcd && dc pull && dcud'
alias dce='docker exec -it ${PWD##*/} /bin/bash'        # Enter docker shell of container matching current folder
alias dcesh='docker exec -it ${PWD##*/} /bin/sh'        # Enter docker shell of container matching current folder

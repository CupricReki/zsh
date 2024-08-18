# Set docker-compose alias for v1
docker-compose --version &> /dev/null
if [ $? -eq 0 ]; then
  alias dc=docker-compose
fi

# Set docker-compose alias for v2
docker compose --version &> /dev/null
if [ $? -eq 0 ]; then
  alias dc="docker compose"
fi

alias dcd='dc down'
alias dcl='dc logs -f'
alias dcu='dc up'
alias dcud='dc up -d'
alias dcudl='dcud && dcl'
alias dcr='dcd && dcud'
alias dcur='dcd && dc pull && dcud'
alias dce='docker exec -it ${PWD##*/} /bin/bash'        # Enter docker shell of container matching current folder

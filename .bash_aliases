alias tf='terraform'
alias tfip='
  terraform fmt -recursive
  terraform init
  terraform plan
'
alias tflock='
  terraform providers lock \
    -platform=darwin_arm64 \
    -platform=linux_amd64 \
    -platform=linux_arm64
'
alias docker-compose='docker compose'
alias vag='vagrant'

alias ansible-playbook='ansible-playbook --check'
alias ansible-playbook-apply='ansible-playbook'

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

alias aws-sso='aws configure sso --profile default'

# デフォルトブランチ以外のローカルブランチとワークツリーを削除する。
# 残すもの: メイン / 現在地のワークツリー、他プロセス (別の Claude セッション等) が使用中のワークツリー、
# 未コミット変更のあるワークツリー、それらでチェックアウト中のブランチ
_git_cleanup_in_use() {
  local p
  for p in /proc/[0-9]*/cwd; do
    case "$(readlink "$p" 2>/dev/null)/" in "$1"/*) return 0 ;; esac
  done
  return 1
}

git-cleanup() {
  local root current default wt ans
  local -a worktrees=() keep_branches=() branches=()

  root=$(git worktree list --porcelain | sed -n '1s/^worktree //p')
  [ -n "$root" ] || return 1
  current=$(git rev-parse --show-toplevel) || return 1
  default=$(git -C "$root" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null) || {
    echo "origin/HEAD が未設定: git remote set-head origin --auto" >&2
    return 1
  }
  default=${default#origin/}

  keep_branches+=("$(git -C "$root" symbolic-ref --short -q HEAD)")
  while IFS= read -r wt; do
    [ "$wt" = "$root" ] && continue
    [ -d "$wt" ] || continue # 実体の無いものは worktree prune に任せる
    if [ "$wt" = "$current" ] || _git_cleanup_in_use "$wt"; then
      echo "残す (使用中): $wt"
      keep_branches+=("$(git -C "$wt" symbolic-ref --short -q HEAD)")
      continue
    fi
    if [ -n "$(git -C "$wt" status --porcelain)" ]; then
      echo "残す (未コミット変更あり): $wt"
      keep_branches+=("$(git -C "$wt" symbolic-ref --short -q HEAD)")
      continue
    fi
    worktrees+=("$wt")
  done < <(git worktree list --porcelain | sed -n 's/^worktree //p')

  while IFS= read -r b; do
    [ "$b" = "$default" ] && continue
    [[ " ${keep_branches[*]} " == *" $b "* ]] && continue
    branches+=("$b")
  done < <(git for-each-ref --format='%(refname:short)' refs/heads/)

  echo "デフォルトブランチ: $default"
  echo "削除するワークツリー: ${#worktrees[@]} 件"
  [ ${#worktrees[@]} -gt 0 ] && printf '  %s\n' "${worktrees[@]}"
  echo "削除するブランチ: ${#branches[@]} 件"
  [ ${#branches[@]} -gt 0 ] && printf '  %s\n' "${branches[@]}"

  if [ ${#worktrees[@]} -gt 0 ] || [ ${#branches[@]} -gt 0 ]; then
    read -r -p "削除しますか? [y/N] " ans
    [ "$ans" = y ] || return 1
  fi

  for wt in "${worktrees[@]}"; do
    git -C "$root" worktree remove "$wt"
  done
  git -C "$root" worktree prune -v
  # 出力の "(was <sha>)" を git branch <name> <sha> に渡せば復元できる
  [ ${#branches[@]} -gt 0 ] && git -C "$root" branch -D "${branches[@]}"
  return 0
}

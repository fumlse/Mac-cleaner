#!/bin/bash
set -euo pipefail

echo "⚠️ 仅推荐给懂终端且有备份的用户；继续即接受风险 [y/N]"
read -r conf
[[ $conf =~ ^[Yy]$ ]] || exit 0

cleaner_path="/usr/local/bin/safe_cleaner"
sudo tee "$cleaner_path" > /dev/null <<'EOF'
#!/bin/bash
set -euo pipefail

CONF_FILE="$HOME/.safe_cleaner.conf"
[ -f "$CONF_FILE" ] && source "$CONF_FILE"

: ${USER_DIRS:="$HOME/Desktop $HOME/Downloads $HOME/Documents"}
: ${EXCLUDE_EXTENSIONS:="pdf docx xlsx pptx jpg png txt mp4 zip"}
: ${MAX_AGE_DAYS:=30}
: ${DRY_RUN:=true}

main() {
  candidates=()
  while IFS= read -r -d $'\0' f; do
    [[ "$f" == *.* ]] || continue
    ext="${f##*.}"
    [[ " $EXCLUDE_EXTENSIONS " == *" ${ext,,} "* ]] && continue
    candidates+=("$f")
  done < <(find $USER_DIRS -type f -mtime +$MAX_AGE_DAYS -print0 2>/dev/null)

  [ ${#candidates[@]} -eq 0 ] && exit 0

  msg="找到 ${#candidates[@]} 个过期文件\n"
  for f in "${candidates[@]:0:5}"; do
    msg+="• ${f##*/}\n"
  done
  [ ${#candidates[@]} -gt 5 ] && msg+="...和其他 $(( ${#candidates[@]} - 5 )) 个文件"
  $DRY_RUN && msg+="\n⚠️ 测试模式（不会删除）"
  msg+="\n⚠️ 120 秒后自动取消"

  response=$(osascript -e "button returned of (display dialog \"$msg\" buttons {\"取消\",\"删除\"} default button \"取消\" giving up after 120)")
  [ "$response" = "删除" ] || exit 0

  for f in "${candidates[@]}"; do
    if $DRY_RUN; then
      echo "[DRY] 删除: $f"
    else
      rm -f -- "$f"
      echo "删除: $f"
    fi
  done
}

case "${1:-}" in
  --clean) main; exit 0 ;;
esac

last_run="$HOME/.last_safe_clean"
[ -f "$last_run" ] && [ $(date +%s -r "$last_run") -gt $(date -v-1d +%s) ] && exit 0
touch "$last_run"
main
EOF

sudo chmod +x "$cleaner_path"

cat > "$HOME/.safe_cleaner.conf" <<EOF
USER_DIRS="$HOME/Downloads"
EXCLUDE_EXTENSIONS="pdf docx xlsx pptx jpg png txt mp4 zip"
MAX_AGE_DAYS=60
DRY_RUN=true
EOF

crontab -l 2>/dev/null | grep -v "safe_cleaner" | crontab -
echo "0 3 * * * $cleaner_path" | crontab -

echo ""
echo "✅ 安装完成！先备份 → 改配置 → 再执行"
echo "备份: 使用 Time Machine 或手动复制到外部磁盘"
echo "改配置: nano ~/.safe_cleaner.conf"
echo "空运行测试: $cleaner_path --clean"
echo "卸载:"
echo "  crontab -r"
echo "  sudo rm -f $cleaner_path ~/.safe_cleaner.conf ~/.last_safe_clean"

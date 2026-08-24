#!/usr/bin/env bash
# 宿舍管理 App —— 自动上传到 GitHub 并触发 Android 云编译
# 前置：export GH_TOKEN="github_pat_xxx"
# 用法：bash deploy.sh <仓库名> [server_url]
# 说明：用 GitHub Contents API 上传（--resolve 绕过 Steam++ 对 github 的 hosts 劫持），
#       不依赖 git push / 系统 hosts / 管理员权限。每个文件都打印成败，不静默中断。
#       改进：base64 编码用 Python 绝对路径（不依赖 coreutils 的 base64 命令），
#             临时文件写项目目录（避开 Git Bash 下 /tmp 不可写）。
set -u

OWNER=a411579910
REPO="${1:?用法: bash deploy.sh <仓库名> [server_url]}"
SERVER_URL="${2:-https://dorm.fnwork.top}"
: "${GH_TOKEN:?请先 export GH_TOKEN=你的token}"

cd /f/SS/dorm-app

PY="/c/Users/admin/.workbuddy/binaries/python/versions/3.14.3/python.exe"
GHAPI="https://api.github.com/repos/$OWNER/$REPO/contents"
RESOLVE="--resolve api.github.com:443:20.205.243.168"

count=$(git ls-files | wc -l)
echo "准备上传 $count 个文件到 $OWNER/$REPO（后端地址=$SERVER_URL）..."

TMPBODY=".deploy_body.json"
TMPRESP=".deploy_resp.json"

git ls-files | while IFS= read -r f; do
  # 1) 查已存在文件的 sha（用于 update 模式）；不存在则为空
  sha=$(curl -s $RESOLVE \
    -H "Authorization: Bearer $GH_TOKEN" "$GHAPI/$f" \
    | "$PY" -c "import sys,json
try:
    print(json.load(sys.stdin).get('sha',''))
except Exception:
    print('')" 2>/dev/null)

  # 2) 用 Python 读取文件做 base64 并写 body JSON（不依赖 base64 命令）
  "$PY" -c "
import base64, json, sys
f=sys.argv[1]; sha=sys.argv[2]; out=sys.argv[3]
with open(f,'rb') as fh:
    content=base64.b64encode(fh.read()).decode()
if sha:
    body={'message':'update '+f,'content':content,'sha':sha}
else:
    body={'message':'add '+f,'content':content}
open(out,'w').write(json.dumps(body))
" "$f" "$sha" "$TMPBODY"

  # 3) PUT 上传
  code=$(curl -s -o "$TMPRESP" -w "%{http_code}" $RESOLVE \
    -H "Authorization: Bearer $GH_TOKEN" -H "Accept: application/vnd.github+json" -H "Content-Type: application/json" \
    --data-binary @"$TMPBODY" -X PUT "$GHAPI/$f")
  if [ "$code" = "200" ] || [ "$code" = "201" ]; then
    echo "  [OK $code] $f"
  else
    echo "  [FAIL $code] $f"
    head -c 400 "$TMPRESP"; echo
  fi
done

rm -f "$TMPBODY" "$TMPRESP"

echo "=== 触发 Android 云编译 (server_url=$SERVER_URL) ==="
curl -s -o .deploy_dispatch.json -w "dispatch -> HTTP %{http_code}\n" $RESOLVE \
  -H "Authorization: Bearer $GH_TOKEN" -H "Accept: application/vnd.github+json" -H "Content-Type: application/json" \
  -d "{\"ref\":\"main\",\"inputs\":{\"server_url\":\"$SERVER_URL\"}}" \
  "https://api.github.com/repos/$OWNER/$REPO/actions/workflows/build-android.yml/dispatches"
head -c 400 .deploy_dispatch.json; echo
rm -f .deploy_dispatch.json

echo "完成 → 去 https://github.com/$OWNER/$REPO/actions 查看并下载 APK 产物 (dorm-app-android-apk)"

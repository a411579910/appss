#!/usr/bin/env bash
# 宿舍管理 App —— 自动上传到 GitHub 并触发 Android 云编译
# 前置：export GH_TOKEN="github_pat_xxx"
# 用法：bash deploy.sh <仓库名> [server_url]
# 说明：用 GitHub Contents API 上传（--resolve 绕过 Steam++ 对 github 的 hosts 劫持），
#       不依赖 git push / 系统 hosts / 管理员权限。每个文件都打印成败，不静默中断。
set -u

OWNER=a411579910
REPO="${1:?用法: bash deploy.sh <仓库名> [server_url]}"
SERVER_URL="${2:-http://61.240.21.74:8000}"
: "${GH_TOKEN:?请先 export GH_TOKEN=你的token}"

cd /f/SS/dorm-app

GHAPI="https://api.github.com/repos/$OWNER/$REPO/contents"
count=$(git ls-files | wc -l)
echo "准备上传 $count 个文件到 $OWNER/$REPO（后端地址=$SERVER_URL）..."

git ls-files | while IFS= read -r f; do
  b64=$(base64 -w0 "$f")
  # 取已存在文件的 sha（用于更新模式）；不存在则为空
  sha=$(curl -s --resolve api.github.com:443:20.205.243.168 \
    -H "Authorization: Bearer $GH_TOKEN" "$GHAPI/$f" \
    | python -c "import sys,json
try:
    print(json.load(sys.stdin).get('sha',''))
except Exception:
    print('')" 2>/dev/null)
  if [ -n "$sha" ]; then
    python -c "import json,sys;b=sys.argv[1];s=sys.argv[2];open('/tmp/gh_body.json','w').write(json.dumps({'message':'update '+sys.argv[3],'content':b,'sha':s}))" "$b64" "$sha" "$f"
  else
    python -c "import json,sys;b=sys.argv[1];open('/tmp/gh_body.json','w').write(json.dumps({'message':'add '+sys.argv[2],'content':b}))" "$b64" "$f"
  fi
  code=$(curl -s -o /tmp/gh_resp.json -w "%{http_code}" --resolve api.github.com:443:20.205.243.168 \
    -H "Authorization: Bearer $GH_TOKEN" -H "Accept: application/vnd.github+json" -H "Content-Type: application/json" \
    --data-binary @/tmp/gh_body.json -X PUT "$GHAPI/$f")
  if [ "$code" = "200" ] || [ "$code" = "201" ]; then
    echo "  [OK $code] $f"
  else
    echo "  [FAIL $code] $f"
    head -c 400 /tmp/gh_resp.json; echo
  fi
done

echo "=== 触发 Android 云编译 (server_url=$SERVER_URL) ==="
curl -s -o /tmp/gh_dispatch.json -w "dispatch -> HTTP %{http_code}\n" --resolve api.github.com:443:20.205.243.168 \
  -H "Authorization: Bearer $GH_TOKEN" -H "Accept: application/vnd.github+json" -H "Content-Type: application/json" \
  -d "{\"ref\":\"main\",\"inputs\":{\"server_url\":\"$SERVER_URL\"}}" \
  "https://api.github.com/repos/$OWNER/$REPO/actions/workflows/build-android.yml/dispatches"
head -c 400 /tmp/gh_dispatch.json; echo

echo "完成 → 去 https://github.com/$OWNER/$REPO/actions 查看并下载 APK 产物 (dorm-app-android-apk)"

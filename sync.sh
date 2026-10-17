#!/usr/bin/env bash
# 从上游 ddgksf2013/Rewrite 同步配置并重新转换为 Loon 插件。
# 依赖：git、curl、python3、gh（仅用于推送）
set -euo pipefail

UPSTREAM_REPO="ddgksf2013/Rewrite"
SOURCE_REPO="wfordawn/loon-upstream-source"
BRANCH="master"
CONVERTER="http://script.hub/file/_start_/"
CONVERTER_Q="type=qx-rewrite&headers=User-Agent:surge&del=true&jqEnabled=true&target=loon-plugin&category=ddgksf2013"

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }

# 1. 从私有源仓库拉取配置模板（源仓库只读，本仓库只存 Loon/ 产物）
say "拉取源配置 $SOURCE_REPO"
SRC_DIR="${TMPDIR:-/tmp}/loon-upstream-src"
rm -rf "$SRC_DIR"
gh repo clone "$SOURCE_REPO" "$SRC_DIR" -- --depth 1 --quiet 2>/dev/null \
  || { warn "克隆源仓库失败，请检查 gh 登录状态"; exit 1; }
CUR=$(git -C "$SRC_DIR" rev-parse --short HEAD)
PREV=$(cat "$ROOT/.sync-source-rev" 2>/dev/null || true)
if [ "$PREV" = "$CUR" ]; then
  say "源配置无变化（$CUR），退出"
  exit 0
fi
say "源配置版本 $CUR"

# 2. 列出所有配置模板
CONFS=$(cd "$SRC_DIR" && git ls-files | grep -E '\.(conf|cof)$' || true)
[ -z "$CONFS" ] && { warn "未找到配置模板"; exit 1; }
say "发现 $(echo "$CONFS" | wc -l | tr -d ' ') 个配置"

# 3. 转换为 Loon 插件
say "转换中（逐个请求转换服务，较慢）"
python3 - "$CONVERTER" "$CONVERTER_Q" "$UPSTREAM_REPO" "$BRANCH" "$SRC_DIR" <<'PY'
import os, re, sys, urllib.request, urllib.parse

converter, cq, repo, branch, src_dir = sys.argv[1:6]
confs = [l.strip() for l in os.popen('cd "%s" && git ls-files' % src_dir).read().splitlines()
         if re.search(r"\.(conf|cof)$", l.strip())]
ok = fail = 0
for p in confs:
    src = open(os.path.join(src_dir, p), encoding="utf-8", errors="replace").read()
    m = re.search(r"@ScriptName\s+(.+)", src)
    name = m.group(1).strip() if m else os.path.basename(p).rsplit(".", 1)[0]
    fm = re.search(r"@Function\s+(.+)", src)
    desc = fm.group(1).strip() if fm else ""
    cat, fname = p.split("/", 1)
    base = fname.rsplit(".", 1)[0]

    raw_src = f"https://raw.githubusercontent.com/{repo}/{branch}/{p}"  # 上游公共源，供转换服务抓取
    url = (f"{converter}{raw_src}/_end_/{base}.sgmodule?{cq}"
           f"&n={urllib.parse.quote(name, safe='')}")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0 Safari/537.36"})
        body = urllib.request.urlopen(req, timeout=90).read().decode("utf-8", "replace")
    except Exception as e:
        print(f"  ✗ {base}: {e}")
        fail += 1
        continue
    if not body.startswith("#!"):
        print(f"  ✗ {base}: 非插件内容")
        fail += 1
        continue

    body = re.sub(r"^#!name=.*$", lambda _: f"#!name={name}", body, count=1, flags=re.M)
    if desc:
        body = re.sub(r"^#!desc=.*$", lambda _: f"#!desc={desc}", body, count=1, flags=re.M)

    os.makedirs(f"Loon/{cat}", exist_ok=True)
    with open(f"Loon/{cat}/{base}.lpx", "w", encoding="utf-8") as f:
        f.write(body)
    print(f"  ✓ {base} | {name}")
    ok += 1

print(f"\n转换完成：成功 {ok}，失败 {fail}")
sys.exit(1 if fail else 0)
PY

# 4. 重新镜像脚本并改写引用
say "镜像 JS 脚本"
python3 - "$ROOT" <<'PY'
import json, os, re, subprocess, urllib.request

root = os.environ.get("REWRITE_RAW", "https://raw.githubusercontent.com/wfordawn/Rewrite/master/Loon/Scripts/")
urls = set()
for cat in os.listdir("Loon"):
    d = f"Loon/{cat}"
    if not os.path.isdir(d) or cat == "Scripts":
        continue
    for f in os.listdir(d):
        if f.endswith(".lpx"):
            t = open(f"{d}/{f}", encoding="utf-8").read()
            urls.update(re.findall(r"script-path=(\S+?)(?=,|\s|$)", t))

os.makedirs("Loon/Scripts", exist_ok=True)
mapping, missing = {}, []
for u in sorted(urls):
    if re.match(r"https://raw\.githubusercontent\.com/wfordawn/Rewrite/", u):
        continue
    base = re.sub(r"\?.*$", "", u.rsplit("/", 1)[-1])
    if "gist.githubusercontent.com" in u:
        base = "gist_" + u.split("/")[4][:8] + "_" + base
    elif "BiliUniverse" in u:
        base = "biliuniverse_" + base
    try:
        req = urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"})
        data = urllib.request.urlopen(req, timeout=90).read()
        if not data:
            raise ValueError("空文件")
    except Exception as e:
        print(f"  ! 跳过 {base}: {e}")
        missing.append(u)
        continue
    open(f"Loon/Scripts/{base}", "wb").write(data)
    mapping[u] = root + base
    print(f"  ✓ {base}")

missing_set = set(missing)
for cat in os.listdir("Loon"):
    d = f"Loon/{cat}"
    if not os.path.isdir(d) or cat == "Scripts":
        continue
    for f in os.listdir(d):
        if not f.endswith(".lpx"):
            continue
        p = f"{d}/{f}"
        t = open(p, encoding="utf-8").read()
        def rep(m):
            u = m.group(1).strip()
            return "script-path=" + mapping[u] if u in mapping else m.group(0)
        nt = re.sub(r"script-path=(\S+?)(?=,|\s|$)", rep, t)
        if nt != t:
            open(p, "w", encoding="utf-8").write(nt)

if missing_set:
    print(f"\n{len(missing_set)} 个脚本上游已失效：")
    for u in sorted(missing_set):
        print("  -", u)
PY

# 5. 重建 index.json
say "重建 index.json"
python3 <<'PY'
import json, os, re

items = []
for cat in sorted(os.listdir("Loon")):
    d = f"Loon/{cat}"
    if not os.path.isdir(d) or cat == "Scripts":
        continue
    for f in sorted(os.listdir(d)):
        if not f.endswith(".lpx"):
            continue
        t = open(f"{d}/{f}", encoding="utf-8").read()
        g = lambda k: (re.search(rf"^#!{k}=(.*)$", t, re.M) or [None, ""])[1].strip()
        secs = []
        for m in re.finditer(r"^\[([^\]]+)\]", t, re.M):
            body = t[m.end():]
            nxt = re.search(r"^\[", body, re.M)
            body = body[:nxt.start()] if nxt else body
            n = sum(1 for l in body.splitlines() if l.strip() and not l.strip().startswith("#"))
            secs.append(f"{m.group(1)}({n})")
        ext = [u for u in re.findall(r"script-path=(\S+?)(?=,|\s|$)", t)
               if "wfordawn/Rewrite" not in u]
        items.append({
            "name": g("name"), "desc": g("desc"), "category": cat,
            "file": f"{d}/{f}", "icon": g("icon"), "tag": g("tag"),
            "size": len(t.encode()), "sections": secs,
            "scripts": len(re.findall(r"script-path=", t)),
            "external": sorted(set(ext)),
        })
json.dump({"author": "ddgksf2013",
           "upstream": "https://github.com/ddgksf2013/Rewrite",
           "format": "Loon plugin (.lpx)",
           "count": len(items), "plugins": items},
          open("index.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)
os.system("cp index.json docs/index.json")
print(f"index.json: {len(items)} 个插件")
PY

# 6. 提交推送
if git diff --quiet; then
  say "内容无变化，无需提交"
  exit 0
fi
say "提交并推送"
git add -A
git -c user.name="$(gh api user -q .login)" \
    -c user.email="$(gh api user -q .login)@users.noreply.github.com" \
    commit -q -m "Sync upstream: $(date '+%Y-%m-%d %H:%M')"
echo "$CUR" > "$ROOT/.sync-source-rev"
git push origin "$BRANCH"
say "完成。页面 1-2 分钟后更新：https://wfordawn.github.io/Rewrite/"

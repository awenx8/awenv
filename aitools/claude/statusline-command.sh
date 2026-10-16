#!/usr/bin/env bash
# Claude Code statusline: 项目名 · git 分支 · 模型名 · 上下文进度条
# Claude Code 通过 stdin 传入 JSON；任何字段缺失都静默降级，绝不写 stderr。
# 用量直接读 payload 的 context_window.total_input_tokens，无需再解析 transcript。
# 热路径只起 1 个子进程（jq 取字段；git 仅 TTL 过期时启动），实测约 5-6ms。
# jq 启动本身约 1.85ms 是地板，过滤器只再占约 0.35ms，压缩它收益有限。
# 解析 transcript 的退化路径约 13ms，仍在噪声范围内可接受。

IFS= read -r -d '' json || true
[ -n "$json" ] || exit 0

E=$'\e'
rst=$E'[0m'
dim=$E'[2m'
sep="${dim} · ${rst}"
bar_grey=$E'[90m'   # 空段前景色；勿用 dim，faint 属性会改变 █ 的字形字宽
BAR_WIDTH=16   # 进度条总宽，满格方块

# ---- 解析 jq；找不到就只显示项目名 ----
JQ=''
if command -v jq >/dev/null 2>&1; then
  JQ=jq
elif [ -x "$HOME/.local/bin/jq.exe" ]; then
  JQ="$HOME/.local/bin/jq.exe"
elif [ -x "$HOME/.local/bin/jq" ]; then
  JQ="$HOME/.local/bin/jq"
fi

if [ -z "$JQ" ]; then
  # 冒号两侧空白要可选：payload 是 JSON.stringify 出的紧凑格式，没有空格
  d=$(printf '%s' "$json" | sed -n 's/.*"current_dir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
  [ -z "$d" ] && d=$(printf '%s' "$json" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
  [ -z "$d" ] && d="$PWD"
  d=${d//\\/}
  printf '%s[1;34m%s%s[0m\n' "$E" "${d##*/}" "$E"
  exit 0
fi

# ---- 一次 jq 取回全部 payload 字段（ 分隔）----
# used / cw 放最后：为空时 read 仍能正确留空。
fields=$("$JQ" -r '
    [ (.workspace.current_dir // .cwd // ""),
      (.model.display_name // .model.id // ""),
      (.model.id // ""),
      (.transcript_path // ""),
      (.context_window.context_window_size // .context_window.limit_tokens //
       .context_window.max_input_tokens // .context_window.max_tokens // ""),
      (.context_window.total_input_tokens // "") ]
    | map(tostring) | join("\u0001")' <<<"$json" 2>/dev/null)
IFS=$'\001' read -r cwd model model_id transcript cw used <<<"$fields"

# ---- 项目名：工作目录最后一段 ----
[ -n "$cwd" ] || cwd="$PWD"
cwd=${cwd//\\/}
cwd=${cwd%/}
project=${cwd##*/}
[ -n "$project" ] || project="$cwd"

# ---- git 分支（5 秒 TTL 缓存；命中时不起 git 进程）----
# 单文件缓存：首字段时间戳，其余为分支名。校验与取值共用一次 read。
# 只写一个文件，避免内容与时间戳写入之间被杀导致半新半旧。
git_seg=''
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  key=${cwd//[![:alnum:]]/_}
  cache="${TMPDIR:-/tmp}/claude-sl-git-${key}"
  secs=$(( ${EPOCHREALTIME%.*} ))

  br=''
  hit=0
  if [ "$secs" -gt 0 ] && [ -r "$cache" ]; then
    # 注意不能写 IFS= read：空 IFS 会连字段切分一起禁用，整行会全进 ts
    read -r ts br <"$cache" 2>/dev/null
    # ts 取自磁盘，先校验再进算术。${#ts}<=10 拦截超 int64 的纯数字，
    # 否则 -gt 报 "integer expected" 漏到 stderr。
    if [[ "$ts" =~ ^[0-9]+$ ]] && [ "${#ts}" -le 10 ] && [ "$ts" -gt 0 ] \
       && [ $(( secs - ts )) -lt 5 ]; then
      hit=1
    fi
  fi

  if [ "$hit" -eq 0 ]; then
    # -uno 跳过未跟踪文件扫描（status 最慢的部分）；只用首行的分支头
    st=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" status --porcelain=v1 --branch \
        --untracked-files=no 2>/dev/null)
    br=${st%%$'\n'*}
    br=${br#'## '}
    br=${br%%\.\.\.*}
    printf '%s %s\n' "$secs" "$br" >"$cache" 2>/dev/null
  fi

  case "$br" in
    *'(no branch)'*) br="@$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-parse --short HEAD 2>/dev/null)" ;;
    'No commits yet on '*) br=${br#'No commits yet on '} ;;
  esac

  [ -n "$br" ] && git_seg="${E}[1;35m${br}${rst}"
fi

# ---- 上下文使用量 ----
# 首选 payload 自带的 context_window.total_input_tokens（含 cache 读写）；
# 旧版 CLI 没有该字段时才退回解析 transcript 里最后一条主链 assistant 的 usage。
if ! [[ "$used" =~ ^[0-9]+$ ]] && [ -n "$transcript" ] && [ -f "$transcript" ]; then
  # 必须先过滤再取首行：-m1 放在第一个 grep 时，若最后一条 assistant 是 sidechain，
  # 会先取到它、再被 grep -v 丢掉，used 静默保持 0，进度条永远显示 0%。
  # 末尾 head -n1 靠 SIGPIPE 让上游 grep 提前退出，不会全量扫完文件。
  line=$(tac "$transcript" 2>/dev/null |
         grep '"type":"assistant"' | grep -v '"isSidechain":true' | head -n1)
  if [ -n "$line" ]; then
    used=$("$JQ" -r '
        (.message.usage |
         ((.input_tokens // 0) + (.cache_creation_input_tokens // 0)
          + (.cache_read_input_tokens // 0)))' <<<"$line" 2>/dev/null)
  fi
fi

# ---- 上下文进度条：始终显示，未对话时 used 为 0 ----
[[ "$used" =~ ^[0-9]+$ ]] || used=0
total="$cw"
if ! [[ "$total" =~ ^[0-9]+$ ]] || [ "$total" -le 0 ]; then
  # 方括号必须用反斜杠转义，不能用单引号包裹：单引号把反斜杠也变成字面字符，
  # 于是 *'\[1m\]' 永不命中。同理 *1m 要求以 "1m" 结尾，而真实 id 是
  # claude-opus-5-5[1m]（以 ] 结尾），同样不命中，1M 模型会被误判成 200k。
  case "$model_id" in
    *\[1m\]*) total=1000000 ;;
    *\[2m\]*) total=2000000 ;;
    *) total=200000 ;;
  esac
fi

pct=$(( used * 100 / total ))
[ "$pct" -gt 100 ] && pct=100
[ "$pct" -lt 0 ] && pct=0

# 全部用满格方块，首尾不留半格空隙，行内对齐才稳定
filled=$(( (pct * BAR_WIDTH + 50) / 100 ))
[ "$filled" -gt "$BAR_WIDTH" ] && filled=$BAR_WIDTH
printf -v pad '%*s' "$BAR_WIDTH" ''   # -v 直接赋值给变量，比 $(printf …) 少起一个子进程
bar_f="${pad:0:filled}"
bar_f=${bar_f// /█}                        # 填充段
bar_e="${pad:filled}"
bar_e=${bar_e// /█}                        # 空段同字形同字宽，只用颜色区分

case "$pct" in
  8[0-9] | 9[0-9] | 100) c='1;31' ;;
  5[0-9] | 6[0-9] | 7[0-9]) c='1;33' ;;
  *) c='32' ;;
esac

fmt() { # 结果写入全局 FMT，避免命令替换再起子进程
  local n=$1
  if [ "$n" -ge 1000000 ]; then FMT="$((n / 1000000)).$(((n / 100000) % 10))M"
  elif [ "$n" -ge 1000 ]; then FMT="$(((n + 50) / 1000))k"
  else FMT="$n"
  fi
}
fmt "$used"; t1=$FMT
fmt "$total"; t2=$FMT
ctx_seg="${E}[${c}m${bar_f}${rst}${bar_grey}${bar_e}${rst} ${E}[${c}m${pct}%${rst}  ${dim}${t1}/${t2}${rst}"

# ---- 拼装 ----
out="${E}[1;34m${project}${rst}"
[ -n "$git_seg" ] && out+="${sep}${git_seg}"
[ -n "$model" ] && out+="${sep}${E}[1;36m${model}${rst}"
[ -n "$ctx_seg" ] && out+="${sep}${ctx_seg}"
printf '%s\n' "$out"

# 常用工具安装与设置
#
# 运行环境: 所有配方在 POSIX shell(sh)中执行,适用于 Linux、macOS,
# 以及 Windows 上的 WSL / Git Bash
# 设计约定: 幂等且可重复执行,已存在的命令直接跳过,不覆盖用户已有配置
#
# 用法:
#   just             # 列出所有任务
#   just setup       # 安装全部常用工具
#   just cargo-tools # 只安装 Rust 工具
#   just claude      # 列出 Claude Code 子项目的全部任务

# 列出任务时一并显示各配方紧邻上方的描述行
set default-list := true

# 通用守卫: 命令已存在则跳过,否则执行安装命令
# 用法: require <cmd> <安装命令>
# 先补全 cargo 安装目录,否则刚装好的工具会被判为缺失
require := 'export PATH="$HOME/.cargo/bin:$PATH"; require() { tool="$1"; if command -v "$tool" >/dev/null 2>&1; then echo "✓ $tool 已安装,跳过"; else shift; echo ">> 安装 $tool"; eval "$@" || echo "跳过 $tool"; fi; }'

# 安装全部工具
setup: apt rust cargo-tools python bun node sqlx proxy \
       rtk git-hooks gui-tools
    @echo "✅ 常用工具安装完成"
    @echo "💡 提示: 新安装的工具可能需要执行 source $HOME/.bashrc 或 source $HOME/.zshrc 或重开终端才能使用"

# 转发到子项目: 进入 aitools/claude/ 执行其 justfile 中的命令
# 用法: just claude setup / just claude config / just claude statusline
claude *args: setup
    @cd "{{ justfile_directory() }}/aitools/claude" && just {{ args }}

# 安装 apt 基础工具
apt:
    @{{require}}; require fzf 'sudo apt install -y fzf tmux jq gh git'

# 安装 Rust 工具链
rust:
    @{{require}}; require rustc 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'

# 安装 Rust 工具
cargo-tools: rust
    @{{require}}; require cargo-binstall 'cargo install cargo-binstall'
    # 条目格式 crate:二进制名, 全就绪则整体跳过
    @missing=""; \
    for pair in \
        bat:bat \
        bottom:btm \
        eza:eza \
        fd-find:fd \
        git-delta:delta \
        just:just \
        ripgrep:rg \
        rumdl:rumdl \
        sqlx-cli:sqlx \
        starship:starship \
        tokei:tokei \
        zoxide:zoxide; do \
        crate="${pair%%:*}"; \
        bin="${pair#*:}"; \
        if command -v "$bin" >/dev/null 2>&1; then \
            echo "✓ $crate 已安装,跳过"; \
        else \
            echo ">> $crate 缺失"; \
            missing="$missing $crate"; \
        fi; \
    done; \
    if [ -n "$missing" ]; then \
        echo ">> 安装 Rust 工具:$missing"; \
        cargo-binstall -y $missing || echo "跳过缺失的 Rust 工具"; \
    else \
        echo "✓ Rust 工具均已安装,跳过"; \
    fi

# 安装 sqlx-cli(无预编译包,需源码编译;rustls 为纯 Rust,无需系统 openssl)
sqlx: rust
    @{{require}}; require sqlx 'cargo install sqlx-cli'

# 托管 Python 版本:安装与全局默认版本共用
python_version := '3.12'

# 安装 Python 工具链(uv + 托管 Python,并设为全局默认版本)
python: rust
    @{{require}}; require uv 'cargo install --locked uv'
    @sed -i '/^# Python 虚拟环境/d; /^source \.venv\/bin\/activate$/d' "$HOME/.bashrc" 2>/dev/null || true
    @printf '\n# Python 虚拟环境\nsource .venv/bin/activate\n' >> "$HOME/.bashrc"
    @echo "✅ 已写入 source .venv/bin/activate 到 $HOME/.bashrc"
    @{{require}}; require mypy 'uv tool install mypy'
    @{{require}}; require pre-commit 'uv tool install pre-commit'
    @{{require}}; require ruff 'uv tool install ruff'
    echo ">> 安装托管 Python {{python_version}} 并设为默认"; \
    uv python install {{python_version}} --default || echo "跳过 Python(安装失败)"; \
    uv python pin --global {{python_version}} || echo "跳过全局默认版本设置"; \

# 安装 bun JavaScript 运行时
bun: node
    @{{require}}; source $HOME/.bashrc; require bun 'npm install -g bun'

# 安装 fnm(Node.js 版本管理器,有预编译包)
fnm: rust
    @{{require}}; require cargo-binstall 'cargo install cargo-binstall'
    @{{require}}; require fnm 'cargo-binstall -y fnm'

# 托管 Node.js 版本:安装与全局默认版本共用
nodejs_version := '24'
# 安装 Node.js 运行时
node: fnm
    @echo ">> 安装 Node.js {{nodejs_version}} 并设为默认"
    @fnm install {{nodejs_version}} || echo "跳过 Node.js(安装失败)"
    @fnm default {{nodejs_version}} || echo "跳过全局默认版本设置"
    @sed -i '/^# fnm(Node.js 版本管理)/d; /^eval ".*\$(fnm env --use-on-cd)"/d' "$HOME/.bashrc" 2>/dev/null || true
    @printf '\n# fnm(Node.js 版本管理)\neval "$(fnm env --use-on-cd)"\n' >> "$HOME/.bashrc"
    @echo "✅ 已写入 fnm 初始化到 $HOME/.bashrc"
    @echo "💡 执行: source $HOME/.bashrc # 生效后 node/npm 可用, 进项目目录自动切换版本"

# 安装 rtk: 压缩命令行输出,降低 AI 编程助手的 token 消耗
rtk: rust
    @{{require}}; require rtk 'cargo install --git https://github.com/rtk-ai/rtk --branch master rtk'
    @echo "💡 执行: rtk init -g # 接入 AI 工具 Claude Code / Copilot"

# 代理端口: 写入 $HOME/.bashrc 的代理别名统一使用该端口
proxy_port := '15490'
# 代理开关名: 开启代理用 px,关闭代理用 unpx
proxy_on := 'px'
proxy_off := 'unpx'
# 写入 $HOME/.bashrc 的代理开关(每次覆盖旧配置)
proxy:
    @sed -i '/^# 代理开关/d; /^{{proxy_on}}()/d; /^{{proxy_off}}()/d' "$HOME/.bashrc" 2>/dev/null || true; \
        printf '\n# 代理开关 ({{proxy_port}})\n{{proxy_on}}() { export http_proxy=http://127.0.0.1:{{proxy_port}} https_proxy=http://127.0.0.1:{{proxy_port}} all_proxy=socks5://127.0.0.1:{{proxy_port}} no_proxy=localhost,127.0.0.1,::1; }\n{{proxy_off}}() { unset http_proxy https_proxy all_proxy no_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY; }\n' >> "$HOME/.bashrc"; \
        echo "✅ 已写入代理开关 {{proxy_on}} / {{proxy_off}} (端口 {{proxy_port}}) 到 $HOME/.bashrc"
    @echo "💡 执行: source $HOME/.bashrc # 生效后用 {{proxy_on}} / {{proxy_off}} 开关代理"

# 打印 GUI 工具的下载地址(macOS/Windows)
gui-tools:
    @echo "提示: 以下桌面应用需自行前往对应地址下载并安装"
    @echo "----------------------------------------"
    @echo "dbx:            https://github.com/t8y2/dbx/releases"
    @echo "docker:         https://www.docker.com/products/docker-desktop/"
    @echo "github-desktop: https://desktop.github.com/"
    @echo "oxideterm:      https://oxideterm.app/zh-hans/"
    @echo "vscode:         https://code.visualstudio.com/download"
    @echo "zed:            https://zed.dev/"
    @echo "百度翻译:        https://fanyi.baidu.com/download"
    @echo "微信:           https://weixin.qq.com/"
    @echo "微信输入法:      https://z.weixin.qq.com/"
    @echo "----------------------------------------"
    @echo "字体下载"
    @echo "----------------------------------------"
    @echo "JetBrains Mono: https://www.jetbrains.com/zh-cn/lp/mono/"
    @echo "LXGW WenKai:    https://github.com/lxgw/LxgwWenKai-Screen/releases"

# 启用 git 提交前钩子
git-hooks:
    @echo ">> 配置 git 全局钩子目录"
    @mkdir -p $HOME/.config/git/hooks
    @if [ -d .husky ]; then \
        cp -f .husky/* $HOME/.config/git/hooks/; \
        chmod +x $HOME/.config/git/hooks/*; \
        echo "✅ Git 钩子已从 .husky 复制到 $HOME/.config/git/hooks/"; \
    else \
        echo ">> 未找到 .husky 目录,跳过复制钩子"; \
    fi

# 格式化代码
fmt:
    @echo ">> 格式化(markdown)"
    @rumdl fmt .

# 检查代码
lint: fix
    @rumdl check .

# 修复代码
fix: fmt
    @echo ">> 修复(markdown)违规"
    @rumdl check --fix .

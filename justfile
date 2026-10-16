# 个人常用工具安装与设置
#
# 用法:
#   just            # 列出所有任务
#   just setup      # 安装全部常用工具
#   just cargo-tools # 只安装 Rust 工具

set default-list := true

# 通用守卫:命令已存在则跳过,否则执行安装命令
# 用法: require <cmd> <安装命令>
require := 'require() { tool="$1"; if command -v "$tool" >/dev/null 2>&1; then echo "✓ $tool 已安装,跳过"; else shift; echo ">> 安装 $tool"; eval "$@" || echo "跳过 $tool(可能已安装)"; fi; }'

# 默认任务:列出全部任务
default:
    @just --list

# 安装全部工具
setup: git rust cargo-tools apt python bun biome pi-agent \
       rtk git-hooks gui-tools
    @echo "✅ 常用工具安装完成"
    @echo "💡 提示: 新安装的工具可能需要执行 source ~/.bashrc 或 source ~/.zshrc 或重开终端才能使用"

# 启用 git 提交前钩子
git-hooks:
    @echo ">> 配置 git 全局钩子目录"
    @mkdir -p ~/.config/git/hooks
    @if [ -d .husky ]; then \
        cp -f .husky/* ~/.config/git/hooks/; \
        chmod +x ~/.config/git/hooks/*; \
        echo "✅ Git 钩子已从 .husky 复制到 ~/.config/git/hooks/"; \
    else \
        echo ">> 未找到 .husky 目录,跳过复制钩子"; \
    fi

# 格式化代码
fmt:
    @echo ">> 格式化(js/ts + markdown)"
    @biome format --write . && rumdl fmt .

# 检查代码
lint: fix
    @rumdl check .
    @biome check .

# 修复代码
fix: fmt
    @echo ">> 修复(js/ts + markdown)违规"
    @biome check --write . && rumdl check --fix .

# 安装 Git
git:
    @{{require}}; \
    if [ "$(uname)" = "Darwin" ]; then \
        require git 'xcode-select --install'; \
    else \
        require git 'sudo apt-get update && sudo apt-get install -y git'; \
    fi

# 安装 apt 基础工具
apt:
    @{{require}}; require fzf 'sudo apt-get update && sudo apt-get install -y fzf tmux jq gh'

# 安装 Rust 工具链(rustup,最小 profile)
rust:
    @{{require}}; require rustc 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y -p minimal'

# 安装 Rust 工具(预编译二进制,快)
cargo-tools: rust
    @{{require}}; require cargo-binstall 'cargo install cargo-binstall'
    @echo ">> 安装 Rust 工具"
    @cargo-binstall -y \
        bat \
        bottom \
        eza \
        fd-find \
        git-delta \
        just \
        ripgrep \
        rumdl \
        sqlx-cli \
        starship \
        tokei \
        zoxide
    @ln -sf "$HOME/.cargo/bin/fdfind" "$HOME/.cargo/bin/fd"

# 安装 Python 工具链(uv + 托管 Python 3.12,并设为全局默认版本)
python:
    @{{require}}; require uv 'curl -LsSf https://astral.sh/uv/install.sh | sh'
    @{{require}}; require ruff 'uv tool install ruff mypy pre-commit'
    @if command -v uv >/dev/null 2>&1; then \
        echo ">> 安装托管 Python 3.12 并设为默认"; \
        uv python install 3.12 --default || echo "跳过 Python(安装失败)"; \
        uv python pin --global 3.12 || echo "跳过全局默认版本设置"; \
    fi

# 安装 bun JavaScript 运行时(安装脚本依赖 unzip)
bun:
    @{{require}}; \
    if ! command -v bun >/dev/null 2>&1 && [ "$(uname)" != "Darwin" ]; then \
        require unzip 'sudo apt-get update && sudo apt-get install -y unzip'; \
    fi
    @{{require}}; require bun 'curl -fsSL https://bun.sh/install | bash'

# 安装 Biome(JS/TS 格式化与检查,通过 bun 全局安装)
biome: bun
    @{{require}}; require biome 'bun install -g @biomejs/biome'

# 安装 Pi Agent(AI 代理工具,通过官方安装脚本)
pi-agent:
    @{{require}}; require pi 'curl -fsSL https://pi.dev/install.sh | sh'

# 初始化 rtk 的 pi agent 全局钩子与 RTK.md
rtk:
    @{{require}}; require rtk 'cargo install --git https://github.com/rtk-ai/rtk'
    @rtk init -g --agent pi

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
    @echo "百度翻译:       https://fanyi.baidu.com/download"
    @echo "微信:           https://weixin.qq.com/"
    @echo "微信输入法:     https://z.weixin.qq.com/"
    @echo "----------------------------------------"
    @echo "字体下载"
    @echo "----------------------------------------"
    @echo "JetBrains Mono: https://www.jetbrains.com/zh-cn/lp/mono/"
    @echo "LXGW WenKai:    https://github.com/lxgw/LxgwWenKai-Screen/releases"

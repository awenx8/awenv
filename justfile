# 个人常用工具安装与设置
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
require := 'require() { tool="$1"; if command -v "$tool" >/dev/null 2>&1; then echo "✓ $tool 已安装,跳过"; else shift; echo ">> 安装 $tool"; eval "$@" || echo "跳过 $tool"; fi; }'

# 安装全部工具
setup: apt rust cargo-tools python bun \
       rtk git-hooks gui-tools
    @echo "✅ 常用工具安装完成"
    @echo "💡 提示: 新安装的工具可能需要执行 source ~/.bashrc 或 source ~/.zshrc 或重开终端才能使用"

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

# 托管 Python 版本:安装与全局默认版本共用
python_version := '3.12'

# 安装 Python 工具链(uv + 托管 Python,并设为全局默认版本)
python:
    @{{require}}; require uv 'curl -LsSf https://astral.sh/uv/install.sh | sh'
    @{{require}}; require mypy 'uv tool install mypy'
    @{{require}}; require pre-commit 'uv tool install pre-commit'
    @{{require}}; require ruff 'uv tool install ruff'
    echo ">> 安装托管 Python {{python_version}} 并设为默认"; \
    uv python install {{python_version}} --default || echo "跳过 Python(安装失败)"; \
    uv python pin --global {{python_version}} || echo "跳过全局默认版本设置"; \

# 安装 bun JavaScript 运行时(安装脚本依赖 unzip)
bun:
    @{{require}}; \
    if ! command -v bun >/dev/null 2>&1 && [ "$(uname)" != "Darwin" ]; then \
        require unzip 'sudo apt install -y unzip'; \
    fi
    @{{require}}; require bun 'curl -fsSL https://bun.sh/install | bash'

# 安装 rtk: 压缩命令行输出,降低 AI 编程助手的 token 消耗
rtk:
    @{{require}}; require rtk 'curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh'
    @echo "💡 执行: rtk init -g # 接入 AI 工具 Claude Code / Copilot"

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
    @echo ">> 格式化(markdown)"
    @rumdl fmt .

# 检查代码
lint: fix
    @rumdl check .

# 修复代码
fix: fmt
    @echo ">> 修复(markdown)违规"
    @rumdl check --fix .

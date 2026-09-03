# 个人常用工具安装与设置
#
# 用法:
#   just            # 列出所有任务
#   just setup      # 安装全部常用工具
#   just cargo-tools bat ripgrep  # 只安装指定 cargo 工具

# 通过 cargo 安装的个人常用 CLI 工具(crate -> 可执行文件名)
# ripgrep(rg) 代码搜索 / bat 语法高亮 cat / fd-find 替代 find
# eza 现代 ls / zoxide 智能 cd / bottom 系统监控
# sqlx-cli 数据库迁移 / rumdl Markdown 检查
CARGO_TOOLS := "bat:bat bottom:btm eza:eza fd-find:fd ripgrep:rg rumdl:rumdl sqlx-cli:sqlx zoxide:zoxide"

# 通用守卫:命令已存在则跳过,否则执行安装命令
# 用法: require <cmd> <安装命令>
require := 'require() { tool="$1"; if command -v "$tool" >/dev/null 2>&1; then echo "✓ $tool 已安装,跳过"; else shift; echo ">> 安装 $tool"; eval "$@" || echo "跳过 $tool(可能已安装)"; fi; }'

# 默认任务:列出全部任务
default:
    @just --list

# 安装全部工具
setup: git rust python bun biome dsh pi-agent cargo-tools gui-tools git-hooks
    @echo "✅ 常用工具安装完成"
    @echo "💡 提示: 新安装的工具可能需要执行 source ~/.bashrc 或 source ~/.zshrc 或重开终端才能使用"

# 启用 git 提交前钩子(执行 .husky/pre-commit)
git-hooks:
    @echo ">> 启用 git pre-commit 钩子"
    @git config core.hooksPath .husky

# 格式化(Biome + rumdl,自动改写)
fmt:
    @echo ">> 格式化(js/ts + markdown)"
    @biome format --write . && rumdl fmt .

# 修复可修复的违规(有残留违规时退出 1)
fix:
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

# 安装 Rust 工具链(rustup)
rust:
    @{{require}}; require rustc 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'

# 安装 Python 工具链(uv + 托管 Python)
python:
    @{{require}}; require uv 'curl -LsSf https://astral.sh/uv/install.sh | sh'
    @if command -v uv >/dev/null 2>&1; then \
        echo ">> 确保托管 Python 可用"; uv python install 3 || echo "跳过 Python(安装失败)"; \
    fi

# 安装 bun JavaScript 运行时
bun:
    @{{require}}; require bun 'curl -fsSL https://bun.sh/install | bash'

# 安装 Biome(JS/TS 格式化与检查,通过 bun 全局安装)
biome: bun
    @{{require}}; require biome 'bun install -g @biomejs/biome'

# 安装 DeepSeek Harness(可组合 AI 代理框架,通过 bun 全局安装)
dsh: bun
    @{{require}}; require dsh 'bun install -g @deepseek-ai/dsh'

# 安装 Pi Agent(AI 代理工具,通过 bun 全局安装)
pi-agent: bun
    @{{require}}; require pi 'bun add -g --ignore-scripts @earendil-works/pi-coding-agent'

# 用 cargo 安装 CLI 工具(已安装则跳过)
# 用法: just cargo-tools [工具名...]
# 示例: just cargo-tools bat ripgrep
cargo-tools *TOOLS:
    @{{require}}; \
    tools="{{TOOLS}}"; \
    if [ -z "$tools" ]; then \
        tools="{{CARGO_TOOLS}}"; \
    else \
        expanded=""; \
        for t in $tools; do \
            match=$(echo "{{CARGO_TOOLS}}" | tr ' ' '\n' | grep -E "^$t:|^$t\$" || true); \
            if [ -n "$match" ]; then \
                expanded="$expanded $match"; \
            else \
                echo "⚠ 未知工具: $t (跳过)"; \
            fi; \
        done; \
        tools="$expanded"; \
    fi; \
    for entry in $tools; do \
        crate="${entry%%:*}"; bin="${entry##*:}"; \
        require "$bin" "cargo install $crate"; \
    done

# 打印 GUI 工具的下载地址(macOS/Windows)
gui-tools:
    @echo "提示: 以下桌面应用需自行前往对应地址下载并安装"
    @echo "----------------------------------------"
    @echo "dbx:            https://github.com/t8y2/dbx/releases"
    @echo "docker:         https://www.docker.com/products/docker-desktop/"
    @echo "github-desktop: https://desktop.github.com/"
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

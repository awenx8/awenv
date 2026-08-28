# 个人常用工具安装与设置
#
# 用法:
#   just            # 列出所有任务
#   just setup      # 安装全部常用工具

# 通过 cargo 安装的个人常用 CLI 工具
# ripgrep(rg) 代码搜索 / bat 语法高亮 cat / fd-find 替代 find
# eza 现代 ls / zoxide 智能 cd / bottom 系统监控
# sqlx-cli 数据库迁移 / rumdl Markdown 检查
CARGO_TOOLS := "bat bottom eza fd-find ripgrep rumdl sqlx-cli zoxide"

# 默认任务:列出全部任务
default:
    @just --list

# 安装全部工具
setup: rust python bun biome cargo-tools gui-tools git-hooks
    @echo "✅ 常用工具安装完成"

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

# 安装 Rust 工具链(rustup)
rust:
    @echo ">> 安装 Rust 工具链"
    @curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || echo "跳过 Rust(可能已安装)"

# 安装 Python 工具链(uv)
python:
    @echo ">> 安装 Python 工具链"
    @curl -LsSf https://astral.sh/uv/install.sh | sh || echo "跳过 Python(可能已安装)"

# 安装 bun JavaScript 运行时
bun:
    @echo ">> 安装 bun"
    @curl -fsSL https://bun.sh/install | bash || echo "跳过 bun(可能已安装)"

# 安装 Biome(JS/TS 格式化与检查,通过 bun 全局安装)
biome: bun
    @echo ">> 安装 Biome"
    @bun install -g @biomejs/biome || echo "跳过 Biome(可能已安装或 bun 不可用)"

# 用 cargo 安装所有 CLI 工具
cargo-tools:
    @for tool in {{CARGO_TOOLS}}; do \
        echo ">> cargo install $tool"; \
        cargo install "$tool" || echo "跳过 $tool(可能已安装)"; \
    done

# 打印 GUI 工具的下载地址(macOS/Windows)
gui-tools:
    @echo "docker:       https://www.docker.com/products/docker-desktop/"
    @echo "git:          https://git-scm.com/downloads"
    @echo "github-desktop: https://desktop.github.com/"
    @echo "vscode:       https://code.visualstudio.com/download"
    @echo "zed:          https://zed.dev/"
    @echo "百度翻译:     https://fanyi.baidu.com/download"
    @echo "微信:         https://weixin.qq.com/"
    @echo "微信输入法:   https://z.weixin.qq.com/"

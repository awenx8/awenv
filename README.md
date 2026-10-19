# awenv

## just

**just** 是一种保存和运行项目命令的便捷方式。官网 <https://just.systems>，文档 <https://just.systems/man/zh/>。

安装（任选其一）:

1. 用 uv 安装（推荐）

```bash
# On macOS and Linux.
curl -LsSf https://astral.sh/uv/install.sh | sh
uv tool install rust-just
```

```bash
# On Windows.
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
uv tool install rust-just
```

2. 用 cargo 安装

```bash
# 跨平台（cargo）
cargo install just
```

## 使用指南

本仓库通过 `justfile` 统一管理常用工具的安装与设置。

### 安装全部常用工具（CLI 工具 + GUI 工具下载地址）

```bash
just setup
```

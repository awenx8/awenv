# awenv

## just

**just** 是一种保存和运行项目命令的便捷方式。官网 <https://just.systems>，文档 <https://just.systems/man/zh/>。

安装（任选其一）:

```bash
# 跨平台（cargo）
cargo install just
```

```bash
# 跨平台（npm）
npm install -g rust-just
```

```bash
# macOS / WSL / Linux
brew install just
```

```bash
# Windows（PowerShell）
scoop install just
```

## 使用指南

本仓库通过 `justfile` 统一管理个人常用工具的安装与设置。

### 安装全部常用工具（CLI 工具 + GUI 工具下载地址）

```bash
just setup
```

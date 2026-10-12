# ~/.config/nushell/config.nu

# 加 PATH
$env.PATH = ($env.PATH | append [
    ~/.cargo/bin
    ~/.local/bin
    ~/.opencode/bin
])

# 关闭启动欢迎横幅
$env.config.show_banner = false

# rustup 常见用法

Rust 工具链管理器：装 rustc/cargo，管理多版本。

## 基本

```bash
rustup update                  # 更新工具链（含 rustup 自身）
rustup toolchain list          # 已装工具链
rustup toolchain install stable/beta/nightly
rustup default stable          # 切默认工具链
rustc --version && cargo --version
```

## 常用

```bash
rustup component add clippy rustfmt     # 加组件
rustup target add x86_64-unknown-linux-musl   # 加交叉编译目标
cargo install <crate>          # 装 Rust 写的 CLI 工具（bat/fd/eza 等）
```

## 注意

- 装完需 source shell rc（PATH 加 ~/.cargo/bin）
- 国内可换源：环境变量 RUSTUP_DIST_SERVER / crates.io 镜像，搜"rust 镜像"按步骤执行

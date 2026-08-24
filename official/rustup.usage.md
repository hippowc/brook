# rustup 常见用法（Rust 工具链管理器）

## 装完必做

```bash
rustup default stable      # 当前 shell 生效（rustc/cargo 可用）
brook mirror crates apply  # 换 cargo 国内源（rsproxy 默认），cargo 下载飞快
```

## 基本

```bash
rustc --version && cargo --version   # 验证
rustup update                        # 升级工具链（含 rustc/cargo）
rustup show                          # 当前 toolchain 与已装组件
cargo new hello && cd hello && cargo run   # 最快跑起一个项目
```

## 进阶

```bash
cargo build --release          # 发布构建（性能版）
cargo test                     # 跑测试
cargo clippy                   # lint（写正式代码建议当门禁）
cargo fmt                      # 格式化
rustup component add rust-analyzer   # 装 LSP（编辑器/agent 用）
cargo add serde               # 加依赖（写进 Cargo.toml）
cargo install <工具>          # 装 CLI 工具（如 bat/fd 的 rust 版）
```

## 排查

- `cargo: command not found` → rustup 没 default 或当前 shell 没重载（`source $HOME/.cargo/env`）
- crates 下载慢/失败 → `brook mirror crates apply`（rsproxy）
- 编译报一堆"crate not found" → 多半网络源问题，先换源再 `cargo build`

# shadowsocks-rust 常见用法（ss 客户端/服务端）

## 配置实践（brook 提供两套，按需执行）

```bash
brook config shadowsocks-rust client    # 配置 client 的 IP+密钥+端口（交互式录入）
brook config shadowsocks-rust server    # 配置服务端（监听端口+密钥+密码）
brook config shadowsocks-rust switch    # 生成 switch 一键开关脚本（pxon/pxoff）
```

## 服务端

```bash
ssserver -c config.json          # 用配置启动
# 常见：systemd 常驻（brook config server 后按提示装 unit）
```

## 客户端

```bash
# local 模式：开本地 SOCKS5 供 curl/浏览器/终端走
sslocal -c config.json
curl --socks5 127.0.0.1:1080 https://example.com   # 验证
export https_proxy=socks5://127.0.0.1:1080 http_proxy=socks5://127.0.0.1:1080
```

## 进阶（系统代理与终端代理）

```bash
# 终端全局走代理（每会话）
export ALL_PROXY=socks5://127.0.0.1:1080
# 仅 GitHub 走代理（包/工具下载友好）
export https_proxy=socks5://127.0.0.1:1080
# 配合 git
git config --global http.proxy socks5://127.0.0.1:1080
```

## 排查

- 连不通 → 端口/密钥/IP 三对照（brook config client 重录）
- 慢 → 换节点/看服务端负载；本地测试 `curl -x socks5://127.0.0.1:1080 -I https://www.google.com`

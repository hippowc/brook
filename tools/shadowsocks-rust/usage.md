# shadowsocks-rust 常见用法

加密 TCP/UDP 中继：应用 ─SOCKS5─▶ sslocal ─加密─▶ ssserver ─明文─▶ 目标。

## 服务端

```bash
ssserver -c svr.json        # 配置示例见 brook shadowsocks-rust config client 生成
sudo ufw allow 8388/tcp && sudo ufw allow 8388/udp
ss -lunpt | grep 8388       # 验证监听
```

常驻用 systemd（/etc/systemd/system/ssserver.service，ExecStart=ssserver -c ...，
Restart=on-failure），`systemctl enable --now ssserver`，日志 `journalctl -u ssserver -f`。

## 客户端

```bash
sslocal -c cli.json         # 本机 127.0.0.1:1080 得到 SOCKS5 出口
curl --socks5-hostname 127.0.0.1:1080 ifconfig.me   # 验证出口 IP
```

CLI 工具走代理靠环境变量：`export ALL_PROXY=socks5://127.0.0.1:1080`
（http_proxy/https_proxy 同设；no_proxy 排除本机/内网）。

## 备忘

```bash
ssservice genkey -m "2022-blake3-aes-256-gcm"   # 2022 加密的密码必须这样生成
nc -vz 服务器IP 8388                              # 从客户端探通
```

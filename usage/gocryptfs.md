# gocryptfs 常见用法

FUSE 文件级加密（AES-256-GCM）：挂载即明文可用，卸载即密文。

## 一次性初始化

```bash
mkdir ~/cipher ~/plain        # cipher=密文(留盘)  plain=挂载点(空目录)
gocryptfs -init ~/cipher      # 输两次密码，打印主密钥
```

**主密钥立刻抄到安全处**：忘密码或 gocryptfs.conf 损坏时它是唯一救援；
但"主密钥+cipher"=免密解密，也要藏好。

## 日常

```bash
gocryptfs ~/cipher ~/plain    # 挂载（输密码），在 ~/plain 里正常读写
fusermount -u ~/plain         # 卸载（macOS 用 umount）
```

## 要点

- 别碰 cipher 目录里的任何文件（gocryptfs.conf 坏了整盘打不开，改一字节密文即拒解）
- 备份 = 整目录拷 cipher；plain 只是影子不占盘
- 重启后密文不丢，重新挂载即可

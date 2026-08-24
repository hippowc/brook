# gocryptfs 常见用法（目录级加密：不需要设备的文件加密方案）

## 概念

把"明文目录"封装成"密文目录"：挂载后读写透明加解密，看磁盘上是密文。
适合：笔记/密钥/备份目录要落地加密，又不想用整盘 LUKS。

## 初始化与挂载

```bash
mkdir -p ~/cipher ~/plain
gocryptfs -init ~/cipher            # 首次：设置密码（生成 masterkey 备份指纹，务必抄下来）
gocryptfs ~/cipher ~/plain          # 每次开机/用时挂载（输密码）
ls ~/plain && echo ok               # 明文可读写
fusermount -u ~/plain               # 卸载（Linux）
umount ~/plain                      # macOS
```

## 进阶

```bash
gocryptfs -init -plaintextnames ~/cipher   # 文件名不加密（只看内容加密，兼容性更好）
gocryptfs -reverse ~/cipher ~/view        # 反向挂载：明文目录变密文快照（备份用）
gocryptfs -passfile keyfile ~/cipher ~/plain   # 用口令文件免交互（脚本用，注意权限)
gocryptfs -config ~/cipher/gocryptfs.conf   # 显式指定配置（多目录共用）
```

## 常规使用

- 挂载点里正常用：`vim ~/plain/note.md`、`git` 等一切照常
- 备份：先 `gocryptfs -reverse` 挂出密文视图再 rsync/rclone 备份

## 排查

- `fuse: device not found` → Linux 缺 fuse：`sudo apt install fuse3`
- 密码写错会拒绝挂载（无提示但什么都看不到）→ 检查大小写
- masterkey 指纹务必保存：丢了密码只能靠它找回，没有就废了

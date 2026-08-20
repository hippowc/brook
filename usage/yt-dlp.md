# yt-dlp 常见用法

从网站提取真实媒体地址并下载。依赖 ffmpeg（合并/转码/抽音）。站点改版频繁，常 `yt-dlp -U` 更新。

## 核心：选格式 -f

```bash
yt-dlp -F URL                                            # 列出所有可选流（排错首选）
yt-dlp -f "bestvideo[height<=1080]+bestaudio/best" URL   # 限 1080p + 兜底
yt-dlp -f "137+251" URL                                  # 直接指定流 ID
yt-dlp URL                                               # 默认即 bestvideo*+bestaudio/best
```

现代站音视频是分离的两条流，`+` 组合下载再合并。

## 命名与配置

```bash
yt-dlp -o "%(uploader)s/%(upload_date)s - %(title)s [%(id)s].%(ext)s" URL
```

偏好固化到 `~/.config/yt-dlp/config`（-f、-o、--download-archive、--embed-subs 等），之后裸跑自动套。

## 只提取不下载

```bash
yt-dlp --print urls URL      # 只吐真实地址
yt-dlp -j URL                # 完整元数据 JSON
ffmpeg -i "$(yt-dlp --print urls URL)" -c copy out.mp4   # 当纯提取器
```

## 其他

```bash
yt-dlp --proxy "socks5h://127.0.0.1:1080" URL   # h=域名走代理解析
yt-dlp -a batch.txt            # 批量（配 --download-archive 只下新的，可挂 cron 追更）
```

# yt-dlp 常见用法（视频下载：YouTube/B站/抖音等 上千站点）

## 基本

```bash
yt-dlp "URL"                    # 下载最佳质量（默认 480p 内）
yt-dlp -f "bv*+ba/b" "URL"      # 视频+音频分离再合并（最佳）
yt-dlp -f mp4 "URL"             # 指定容器格式
yt-dlp -o "~/Downloads/%(title)s.%(ext)s" "URL"
```

## 常用选项

```bash
-a list.txt                     # 批量：文件里每行一个 URL
-x --audio-format mp3           # 只下音频转 mp3
--playlist-start 1 --playlist-end 5   # 播放列表中 1-5 集
-c                              # 断点续传（中断后重跑）
--write-subs --sub-langs "zh-Hans,en"   # 带字幕
--embed-thumbnail --embed-metadata      # 元数据内嵌（本地播放器友好）
```

## 进阶

```bash
--proxy socks5://127.0.0.1:1080  # 走代理（配合 ss 客户端）
-F URL                          # 先列出可用格式再挑
-P ~/media -o "%(playlist)s/%(title)s.%(ext)s"   # 按列表分目录
--download-archive done.txt     # 只下新的（增量）
# 用 cookies 下会员内容：--cookies-from-browser firefox
```

## 排查

- 下载被限速/403 → 加 `--proxy` 或 `-f` 换低码率格式
- 站点反爬 → 更新 yt-dlp：`yt-dlp -U`（自带更新）
- 合并失败 → 需 ffmpeg：装 ffmpeg（系统包/brew）

# Docker 常见用法

Linux 用 brook 内置国内仓库直装（brook install docker）；macOS 用 Docker Desktop（GUI 安装）。
装完新开终端即可用 docker。

## 安装说明

```bash
brook install docker                # 默认 TUNA 源直装 docker-ce（需 root，brook 自动 sudo）
DOCKER_MIRROR=aliyun brook install docker   # 换阿里云源（可选 ustc）
```
> 为什么不用官方脚本：get.docker.com 在国内不可达（连接被重置），brook 改用 TUNA/USTC/阿里云 docker-ce 仓库直装。

## 装完第一步

```bash
sudo usermod -aG docker $USER && newgrp docker   # 当前用户免 sudo 用 docker（重登一次）
docker run --rm hello-world                       # 验证
```

## 高频

```bash
docker ps -a                          # 所有容器
docker images                         # 本地镜像
docker pull <镜像>                     # 拉镜像（国内慢：brook mirror docker apply）
docker run -it --rm ubuntu bash       # 临时起容器
docker exec -it <容器> bash            # 进运行中的容器
docker logs -f <容器>                  # 看日志
docker compose up -d                  # 按 compose 文件起服务
docker system prune -af               # 清理（慎用）
```

## 国内镜像（只加速 pull）

```bash
brook mirror docker apply                  # 写 /etc/docker/daemon.json（默认 DaoCloud）
brook mirror docker apply --mirror 1ms     # 换 1ms（可选 1panel）
sudo systemctl restart docker
docker info | grep -A2 'Registry Mirrors'  # 验证
```

> 注意：registry 镜像**只加速 `docker pull`**，不加速 `docker search`。
> `docker search` 直连 `index.docker.io`，国内通常超时——要么去 hub.docker.com
> 网页搜，要么给 dockerd 配代理（见下）。

## search 走代理（可选；给 daemon 配代理）

```bash
# 若本地有代理（如 ss 客户端 127.0.0.1:1080），让 dockerd 走代理
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf >/dev/null <<'EOF'
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:1080"
Environment="HTTPS_PROXY=http://127.0.0.1:1080"
Environment="NO_PROXY=localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
EOF
sudo systemctl daemon-reload && sudo systemctl restart docker   # 代理端口请按实际改
```

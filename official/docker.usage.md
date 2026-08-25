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

## 国内镜像

```bash
brook mirror docker apply                  # 写 /etc/docker/daemon.json（DaoCloud）
sudo systemctl restart docker
docker info | grep -A2 'Registry Mirrors'  # 验证
```

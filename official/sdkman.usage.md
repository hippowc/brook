# sdkman 常见用法

Java 工具链管理器：装/切换 JDK（Temurin/Zulu/Corretto 等）与 Maven/Gradle 等 JVM 生态工具。

## 基本

```bash
sdk list java                 # 浏览可用 JDK（输出含标识符，如 21.0.5-tem）
sdk install java 21.0.5-tem   # 装指定版本（标识符以 list 输出为准）
sdk install java              # 装当前推荐版本
sdk use java 21.0.5-tem       # 仅当前终端会话切换
sdk default java 21.0.5-tem   # 设默认版本
java -version
```

## 常用

```bash
sdk list                      # 全部可管理候选（java/maven/gradle/kotlin/scala 等）
sdk install maven             # 装 Maven（gradle/kotlin 等同理）
sdk upgrade java              # 升级候选
sdk current                   # 查看当前使用的版本
sdk selfupdate                # 更新 SDKMAN 自身
```

## 注意

- sdk 是 shell 函数：装后新开终端，或先 `source "$HOME/.sdkman/bin/sdkman-init.sh"`
- SDKMAN 无官方国内镜像（上游 issue #1287），下载走 GitHub/API；国内两条对策：
  1. 走代理：`export https_proxy=http://127.0.0.1:<port>` 后再执行 sdk 命令
  2. 绕过 SDKMAN 装 JDK：清华 Adoptium 镜像手动下载（mirrors.tuna.tsinghua.edu.cn/Adoptium）
- 依赖系统装有 zip/unzip（brook 安装前会预检）

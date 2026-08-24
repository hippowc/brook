# SDKMAN 常见用法（Java 工具链管理器：JDK/Maven/Gradle/Scala/Kotlin）

## 前提与生效

```bash
# 依赖 zip/unzip（缺失时 brook 会提示）。sdk 是 shell 函数：
source ~/.sdkman/bin/sdkman-init.sh   # 装完新终端自动有；也可手动 source
sdk version
brook mirror maven apply              # 顺手配 Maven 中央仓国内镜像
```

## 基本

```bash
sdk list java                 # 看所有 JDK 发行版（Temurin/Zulu/Oracle…）
sdk install java 21.0.5-tem    # 装指定 JDK
sdk default java 21.0.5-tem    # 设全局默认
sdk use java 17.0.15-tem       # 当前目录用
sdk current                   # 看当前
sdk list maven && sdk install maven 3.9.9
```

## 进阶

```bash
sdk upgrade                  # 升级已装版本
sdk uninstall java 17…       # 卸载
sdk offline                  # 离线模式（用本地缓存）
sdk env                      # 按 .sdkmanrc 自动切版本（配合 sdk env init）
```

## 排查

- `sdk: command not found` → 新开终端或 source init 脚本；确认 ~/.sdkman/bin 存在
- 装大版本慢 → 换国内镜像 JDK 发行版（如 Alibaba Dragonwell / TencentKona），或挂代理
- `sdk` 与系统已有 java 冲突 → 用 `sdk default` 并注意 JAVA_HOME 指向

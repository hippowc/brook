# git 常见用法

系统级版本控制。brook 不装 git（apt/brew/CLT 自带），只提供配置实践：
`brook config git github-ssh` 生成 SSH key 并引导添加公钥。

## 初次上台：身份与密钥

```bash
git config --global user.name  "你的名字"
git config --global user.email "you@example.com"
brook config git github-ssh        # 生成 ed25519 key + 引导加公钥到 GitHub
ssh -T git@github.com              # 验证（Hi <user>! = 成功）
```

## 高频

```bash
git clone git@github.com:owner/repo.git   # SSH 克隆（比 HTTPS 不用输密码）
git add -A && git commit -m "msg"         # 提交
git pull --rebase                         # 拉取并变基（保持线性历史）
git push                                  # 推送
git status -sb                            # 简短状态 + 分支上游信息
git log --oneline --graph -20             # 图形化最近 20 条
```

## 撤销与急救

```bash
git restore file                 # 丢弃工作区改动（未 add）
git restore --staged file        # 撤销 add（保留改动）
git commit --amend               # 改最近一次提交的信息
git reset --hard HEAD~1          # 回退到上一个提交（慎用）
git reset --soft HEAD~1          # 撤销提交但保留改动
git stash && git stash pop       # 临时保存/恢复未提交改动
```

## 分支

```bash
git switch -c feat/xxx           # 新建并切换分支
git branch -d feat/xxx           # 删除已合并分支
git merge --no-ff feat/xxx       # 合并（保留合并提交）
git push -u origin feat/xxx      # 首次推送新分支
```

## 排查

- 推送 403/权限错 → 公钥没加或没验证：`brook config git github-ssh` + `ssh -T git@github.com`
- `ssh: connect to host github.com port 22` 超时 → 国内网络改走 443：`~/.ssh/config` 加
  `Host github.com` + `  Hostname ssh.github.com` + `  Port 443`

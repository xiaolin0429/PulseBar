[English](CONTRIBUTING.md) | 简体中文

# 贡献与分支管理流程

固定采用 `feat/* -> dev -> main`：`main` 是发行基线，`dev` 是集成分支。两者均必须通过 PR、必需检查和讨论解决后合入，禁止直接推送、强推和删除，不配置绕过者。按单人维护方式，不强制其他协作者人工批准。

## 开发与合入

```sh
git fetch origin
git switch -c feat/your-change origin/dev
# 完成修改、本地验证并提交。
git push -u origin feat/your-change
```

先向 `dev` 发起 PR，全部检查通过后使用 **Create a merge commit** 合入。集成检查完成后，再从本仓库的 `dev` 向 `main` 发起独立 PR，重新执行所有检查。功能分支不能直接合入 `main`。`Branch flow` 使用目标分支上可信的工作流，只检查 PR 元数据，不检出或执行 PR 代码。

必过检查为 **Branch flow**、**Build and test**、**Dependency review**、**CodeQL (Swift)**、**CodeQL (Actions)**，且分支必须跟上目标分支最新提交。CodeQL 覆盖应用、工具和工作流定义；有扫描发现时直接失败，不把“成功上传结果”当成“没有安全问题”。依赖审查阻止新增低危及以上已知漏洞，包含开发依赖；覆盖范围限于 GitHub 可识别的依赖，引入 Swift 依赖时须提交 `Package.resolved` 锁文件。自动扫描通过不等于代码绝对安全。

GitHub 规则集还会强制检查代码扫描结果。禁止为了合入而删除失败检查、修改必过检查名称或放宽规则。即使不强制他人批准，也应仔细审阅 `.github/workflows/` 的改动。仓库管理员仍可编辑规则，这不等同于不可修改的组织级策略。

`dev -> main` 合入后，CI 自动打包并发布对应提交的 GitHub Release。现有 **Build and test** 必过检查也会在合入前验证 Universal 打包。产物、标签、签名边界和重试方式见[自动 GitHub Release](README.zh-CN.md#自动-github-release)。

## 发行后同步

使用合并提交保留分支祖先关系。`dev -> main` 合入后，`main` 会增加合并提交，应通过功能分支同步回 `dev`，不能直接推送：

```sh
git fetch origin
git switch -c feat/sync-main origin/dev
git merge origin/main
git push -u origin feat/sync-main
# 创建 feat/sync-main -> dev 的 PR，等待所有检查通过。
```

之后从更新后的 `origin/dev` 创建新功能分支。发行后不要删除长期保留的 `dev` 分支。

## 本地验证

运行 `swift test` 和 README 中的 macOS Debug 构建命令。GitHub CI 使用托管 macOS runner，不能替代真机 UI/性能验收或 Apple 发行签名。

Git 提交身份与推送认证彼此独立。提交时使用预期的公开作者身份，不得提交私钥或个人 IDE 配置。

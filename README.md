# TeamTalk Docker 镜像

TeamTalk 与 TeamTalk Pro 服务端的独立容器构建项目。

- `teamtalk/`：TeamTalk 镜像。
- `teamtalkpro/`：TeamTalk Pro 镜像。
- `VERSION`：默认服务端版本。
- `build.sh`：使用 Docker Buildx 构建并推送两个镜像，默认平台为 `linux/amd64,linux/arm64`，默认镜像命名空间为 `hejd`。

```bash
./build.sh --help
./build.sh --version v5.21 --namespace hejd
```

需要可用的 Docker Buildx，以及目标镜像仓库的登录权限。可使用脚本参数或环境变量覆盖版本、命名空间和构建平台。

本仓库于 2026-10-11 从 `dbqn/lqbzfile/tt-docker` 提取，保留原目录的提交历史。

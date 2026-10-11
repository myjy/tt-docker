# TeamTalk 5 Server / 普通版服务端

[中文](#中文) | [English](#english)

## 中文

由 hejd 维护的 TeamTalk 服务端镜像，使用 BearWare 发布的 `tt5srv`。支持 `linux/amd64` 和 `linux/arm64`，Docker 会自动选择对应架构。

**已有有效配置时，把配置所在目录映射到容器的 `/etc/teamtalk`，直接启动即可。镜像已经设置启动命令，无需额外填写 `command`、`entrypoint`、`-nd` 或 `-wd`。**

配置文件名为 `tt5srv.xml`。容器内统一使用 `/etc/teamtalk`；宿主机目录可以自行选择。需要 Pro 的加密和 BearWare WebLogin 功能，请使用 [hejd/teamtalkpro](https://hub.docker.com/r/hejd/teamtalkpro)。

### 已有配置：直接启动

将下面内容保存为 `compose.yaml`。把已有配置放入同目录的 `data` 文件夹，也可以只修改挂载配置冒号左侧的 `./data`，指向已有目录；右侧保持 `/etc/teamtalk`。

```yaml
services:
  teamtalk:
    image: hejd/teamtalk:latest
    container_name: teamtalk
    restart: unless-stopped
    ports:
      - "10333:10333/tcp"
      - "10333:10333/udp"
    volumes:
      - ./data:/etc/teamtalk
```

目录示例：

```text
compose.yaml
data/
  tt5srv.xml
  files/          # 如果启用了文件共享
```

在 `compose.yaml` 所在目录执行：

```sh
docker compose up -d
docker compose logs --tail 100 teamtalk
```

已有配置中的文件存储路径也必须是容器内可见的路径，例如 `/etc/teamtalk/files`。保留原来的配置文件和上传文件，不要重新运行初始化向导覆盖已有设置。

使用 Docker Desktop 时选择 Linux 容器；Windows 用户可在 PowerShell 中运行上述命令。

### 首次使用：先配置，再启动

使用同一份 `compose.yaml`，先创建文件存储目录，再运行交互式向导：

```sh
docker compose run --rm teamtalk mkdir -p /etc/teamtalk/files
docker compose run --rm -it teamtalk -wizard
```

按向导设置服务器名称、用户数量和其他选项：

- TCP、UDP 端口均保留 `10333`，与上面的映射一致。
- 如启用文件共享，存储目录填写 `/etc/teamtalk/files`，并设置合适的磁盘配额。
- 在用户账户菜单选择 `Create new user account`，自行设置用户名和密码；需要管理员时选择 `Administrator`。镜像不预设登录账户。
- 最后确认保存，看到 `Changes saved.` 后，再执行 `docker compose up -d`。

向导生成的 `tt5srv.xml` 会保存在宿主机的 `data` 目录；后续启动不需要再传 `-wizard`。

### 客户端连接

在 TeamTalk 客户端填写服务器的地址、TCP 端口 `10333`、UDP 端口 `10333`，以及配置中创建的账户。公网访问时，需要在宿主机防火墙和云安全组放行 TCP、UDP 两种协议；处于路由器后方时还需要端口转发。

如果宿主机的 `10333` 已被占用，可把两项映射改为 `10334:10333/tcp`、`10334:10333/udp`，客户端相应填写 `10334`。不要只映射 TCP。

### 数据、权限与日常管理

配置和放在 `/etc/teamtalk` 下的文件会保存到挂载目录。删除或重建容器后，继续挂载同一个目录即可；备份时应包含整个数据目录。日志可通过 `docker compose logs` 查看；文件日志是否生成由服务端配置决定。

可选环境变量：

| 变量 | 默认值 | 用途 |
| --- | --- | --- |
| `TZ` | `Asia/Shanghai` | 容器时区 |
| `uid` | `0` | 服务端运行用户的数字 UID |
| `gid` | 与 `uid` 相同 | 服务端运行组的数字 GID |
| `chown` | `auto` | `auto` 在指定非零 UID/GID 时递归设置数据目录所有者；`true` 总是设置，`false` 不修改 |

需要非 root 运行时，可在服务配置中加入以下内容，数字按实际需要替换；变量名 `uid`、`gid` 使用小写：

```yaml
    environment:
      uid: "1000"
      gid: "1000"
```

自动设置所有者会作用于映射的宿主机目录。若使用 `chown: "false"` 或 Compose 的 `user:`，请自行确保该用户能读写数据目录。

修改配置前先停止服务，避免正在运行的服务端保存设置时覆盖修改：

```sh
docker compose stop teamtalk
docker compose run --rm -it teamtalk -wizard
docker compose up -d
```

升级前先停止服务并备份 `data`，然后拉取最新镜像并重建容器：

```sh
docker compose pull teamtalk
docker compose up -d teamtalk
```

示例使用 `latest`，指向本仓库最近发布的镜像。新版本发布后，执行上述拉取与重建命令即可升级，无需修改 Compose 中的镜像标签。如需固定某个版本，请从仓库的 [Tags 页面](https://hub.docker.com/r/hejd/teamtalk/tags) 选择已发布的版本标签。

### 常见问题

- **无法登录：**确认挂载目录中确实有 `tt5srv.xml`，并且已创建用户账户。只有空目录时，不会自动获得管理员账户。
- **连不上或没有声音：**检查 TCP 和 UDP 是否都已映射、放行，以及客户端端口是否与宿主机映射一致。
- **无法保存配置或上传文件：**检查目录写权限、文件存储路径和配额。迁移配置时，旧机器上的绝对路径需要对应到容器内路径。
- **修改后未生效：**停止容器后修改配置，再重新启动；确认修改的是实际挂载的目录。

服务端功能和许可由 BearWare 提供，详情参见 [TeamTalk 下载页面](https://bearware.dk/?page_id=353) 和 [官方服务端使用说明](https://github.com/BearWare/TeamTalk5/blob/master/Documentation/TeamTalk/server.md)。

---

## English

Maintained by hejd, this image runs the `tt5srv` server distributed by BearWare. It supports `linux/amd64` and `linux/arm64`; Docker selects the matching architecture automatically.

**If you already have a valid configuration, mount its directory at `/etc/teamtalk` in the container and start the image. The startup command is already configured: no additional `command`, `entrypoint`, `-nd`, or `-wd` is needed.**

The configuration file is `tt5srv.xml`. The container uses `/etc/teamtalk`; you can choose any suitable directory on the host. For Pro features such as encrypted connections and BearWare WebLogin, use [hejd/teamtalkpro](https://hub.docker.com/r/hejd/teamtalkpro).

### Existing configuration: start directly

Save the following as `compose.yaml`. Put your existing configuration in a `data` folder beside it, or change only `./data` on the left side of the volume mapping to your existing directory. Keep `/etc/teamtalk` on the right.

```yaml
services:
  teamtalk:
    image: hejd/teamtalk:latest
    container_name: teamtalk
    restart: unless-stopped
    ports:
      - "10333:10333/tcp"
      - "10333:10333/udp"
    volumes:
      - ./data:/etc/teamtalk
```

Example directory layout:

```text
compose.yaml
data/
  tt5srv.xml
  files/          # If file sharing is enabled
```

Run these commands from the directory containing `compose.yaml`:

```sh
docker compose up -d
docker compose logs --tail 100 teamtalk
```

File storage paths in your existing configuration must also point to locations visible inside the container, such as `/etc/teamtalk/files`. Keep your existing configuration and uploaded files; do not rerun initial setup over an existing configuration.

With Docker Desktop, use Linux containers. Windows users can run these commands in PowerShell.

### First use: configure, then start

Using the same `compose.yaml`, create the file storage directory and run the interactive setup wizard:

```sh
docker compose run --rm teamtalk mkdir -p /etc/teamtalk/files
docker compose run --rm -it teamtalk -wizard
```

Follow the wizard to set the server name, user limit, and other options:

- Keep both TCP and UDP ports at `10333` to match the mappings above.
- If you enable file sharing, enter `/etc/teamtalk/files` as the storage directory and set suitable disk quotas.
- In the user account menu, select `Create new user account` and choose your own username and password. Select `Administrator` if you need an administrator account. The image does not provide a preset login account.
- Confirm that you want to save the settings. After you see `Changes saved.`, run `docker compose up -d`.

The generated `tt5srv.xml` is saved in the host's `data` directory. Subsequent starts do not need `-wizard`.

### Connecting a client

In the TeamTalk client, enter your server address, TCP port `10333`, UDP port `10333`, and an account created in the configuration. For access over the internet, allow both TCP and UDP in the host firewall and any cloud security group. If the server is behind a router, configure port forwarding as well.

If port `10333` is already in use on the host, change the two mappings to `10334:10333/tcp` and `10334:10333/udp`, then use `10334` in the client. Map both TCP and UDP.

### Data, permissions, and maintenance

The configuration and files stored under `/etc/teamtalk` are saved in the mounted directory. Reuse the same directory when deleting or recreating a container, and include the entire data directory in backups. View container logs with `docker compose logs`; whether the server also writes log files depends on its configuration.

Optional environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `TZ` | `Asia/Shanghai` | Container time zone |
| `uid` | `0` | Numeric UID used to run the server |
| `gid` | Same as `uid` | Numeric GID used to run the server |
| `chown` | `auto` | `auto` recursively sets ownership of the data directory when a nonzero UID or GID is specified; `true` always sets ownership; `false` leaves it unchanged |

To run the server as a non-root user, add the following under the service definition. Replace the numbers as needed; the variable names `uid` and `gid` are lowercase:

```yaml
    environment:
      uid: "1000"
      gid: "1000"
```

Automatic ownership changes apply to the mounted host directory. If you use `chown: "false"` or Compose's `user:` setting, ensure that the selected user can read and write the data directory.

Stop the service before editing its configuration so that the running server does not overwrite your changes when it saves settings:

```sh
docker compose stop teamtalk
docker compose run --rm -it teamtalk -wizard
docker compose up -d
```

Before upgrading, stop the service and back up `data`. Then pull the latest image and recreate the container:

```sh
docker compose pull teamtalk
docker compose up -d teamtalk
```

The examples use `latest`, which points to the most recently published image in this repository. After a new release, run the pull and recreate commands above to upgrade without changing the image tag in your Compose file. To pin a specific version, choose a published version tag from the repository's [Tags page](https://hub.docker.com/r/hejd/teamtalk/tags).

### Troubleshooting

- **Cannot log in:** Check that the mounted directory contains `tt5srv.xml` and that user accounts have been created. An empty directory does not provide an administrator account automatically.
- **Cannot connect or no audio:** Check that both TCP and UDP are mapped and allowed, and that the client ports match the host mappings.
- **Cannot save settings or upload files:** Check write permissions, the file storage path, and disk quotas. When migrating a configuration, update absolute paths from the old machine to paths visible inside the container.
- **Changes do not take effect:** Stop the container before editing the configuration, then restart it. Make sure you edited the directory that is actually mounted.

Server features and licensing are provided by BearWare. See the [TeamTalk download page](https://bearware.dk/?page_id=353) and the [official server documentation](https://github.com/BearWare/TeamTalk5/blob/master/Documentation/TeamTalk/server.md).

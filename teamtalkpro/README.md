# TeamTalk 5 Pro Server / Pro 服务端

[中文](#中文) | [English](#english)

## 中文

由 hejd 维护的 TeamTalk Professional 服务端镜像，使用 BearWare 发布的 `tt5prosrv`。支持 `linux/amd64` 和 `linux/arm64`，提供加密连接与 BearWare WebLogin 功能。

**已有有效配置及可用的 BearWare WebLogin 令牌时，把配置所在目录映射到容器的 `/etc/teamtalk`，直接启动即可。镜像已经设置启动命令，无需额外填写 `command`、`entrypoint`、`-nd` 或 `-wd`。**

配置文件名为 `tt5prosrv.xml`。Pro 启动需要获授权使用的 BearWare.dk WebLogin 账户；首次使用请完成下面的配置和认证步骤。普通版位于 [hejd/teamtalk](https://hub.docker.com/r/hejd/teamtalk)。

### 已有配置：直接启动

将下面内容保存为 `compose.yaml`。把已有配置放入同目录的 `data` 文件夹，也可以只修改挂载配置冒号左侧的 `./data`，指向已有目录；右侧保持 `/etc/teamtalk`。

```yaml
services:
  teamtalkpro:
    image: hejd/teamtalkpro:latest
    container_name: teamtalkpro
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
  tt5prosrv.xml
  files/          # 如果启用了文件共享
  server.crt      # 如果启用了加密，使用你自己的证书和文件名
  server.key
```

在 `compose.yaml` 所在目录执行：

```sh
docker compose up -d
docker compose logs --tail 100 teamtalkpro
```

已有配置中的上传目录、证书和私钥路径必须是容器内可见的路径，例如 `/etc/teamtalk/files`、`/etc/teamtalk/server.crt`。普通版和 Pro 应使用各自的数据目录。

使用 Docker Desktop 时选择 Linux 容器；Windows 用户可在 PowerShell 中运行上述命令。

### 首次使用：配置与 BearWare 认证

使用同一份 `compose.yaml`，先创建文件存储目录，再运行交互式向导：

```sh
docker compose run --rm teamtalkpro mkdir -p /etc/teamtalk/files
docker compose run --rm -it teamtalkpro -wizard
```

按向导设置服务器名称和用户账户：

- TCP、UDP 端口均保留 `10333`，与上面的映射一致。
- 如启用文件共享，存储目录填写 `/etc/teamtalk/files`，并设置磁盘配额。
- 需要普通用户名密码账户时，选择 `Create new user account` 并自行设置；需要管理员时选择 `Administrator`。
- 如启用加密，先把证书和私钥放入数据目录，再在向导中填写容器内路径。加密需要在服务端配置中开启，客户端也要选择加密连接。
- 最后确认保存，看到 `Changes saved.`。

随后以前台交互方式启动一次，完成服务端要求的 BearWare WebLogin 认证：

```sh
docker compose run --rm -it teamtalkpro
```

按提示输入获授权的 BearWare 账户，并同意将访问令牌保存到配置文件。首次认证需要能够访问 BearWare 服务。看到服务端已启动后，按 `Ctrl+C` 正常退出，再转为后台运行：

```sh
docker compose up -d
```

如果向导中已经完成认证并保存了有效令牌，可以直接后台启动。令牌保存在挂载目录中的 `tt5prosrv.xml`，后续启动会复用它。服务端的 BearWare 认证和向导里创建的客户端登录账户用途不同，两者都应按需要配置。

### 客户端连接

在 TeamTalk 客户端填写服务器地址、TCP 端口 `10333`、UDP 端口 `10333`，以及配置好的账户。服务端开启加密时，客户端也必须启用加密；证书验证方式参见下方官方文档。

公网访问时，宿主机防火墙和云安全组需要同时放行 TCP、UDP；处于路由器后方时还需要端口转发。若与普通版同时运行，应使用不同的宿主机端口，例如把 Pro 的两项映射改为 `10334:10333/tcp`、`10334:10333/udp`，客户端相应填写 `10334`。

### 数据、权限与日常管理

请持续挂载同一个数据目录，保存配置、WebLogin 令牌、证书及上传文件。备份时应包含整个目录，并妥善保管其中的令牌和私钥。日志可通过 `docker compose logs` 查看；文件日志是否生成由服务端配置决定。

可选环境变量：

| 变量 | 默认值 | 用途 |
| --- | --- | --- |
| `TZ` | `Asia/Shanghai` | 容器时区 |
| `uid` | `0` | 服务端运行用户的数字 UID |
| `gid` | 与 `uid` 相同 | 服务端运行组的数字 GID |
| `chown` | `auto` | `auto` 在指定非零 UID/GID 时递归设置数据目录所有者；`true` 总是设置，`false` 不修改 |

需要非 root 运行时，可在服务配置中加入以下内容，数字按实际需要替换；向导、认证和后台服务应使用相同的 UID/GID：

```yaml
    environment:
      uid: "1000"
      gid: "1000"
```

自动设置所有者会作用于映射的宿主机目录。若使用 `chown: "false"` 或 Compose 的 `user:`，请自行确保该用户能读写配置和文件，并能读取证书及私钥。

修改配置前先停止服务：

```sh
docker compose stop teamtalkpro
docker compose run --rm -it teamtalkpro -wizard
docker compose up -d
```

升级前先停止服务并备份 `data`，然后拉取最新镜像并重建容器：

```sh
docker compose pull teamtalkpro
docker compose up -d teamtalkpro
```

示例使用 `latest`，指向本仓库最近发布的镜像。新版本发布后，执行上述拉取与重建命令即可升级，无需修改 Compose 中的镜像标签。如需固定某个版本，请从仓库的 [Tags 页面](https://hub.docker.com/r/hejd/teamtalkpro/tags) 选择已发布的版本标签。

### 常见问题

- **后台反复要求 BearWare 登录：**停止后台服务，再执行上面的前台交互认证步骤，确认令牌已保存到同一个挂载目录。更改 BearWare 密码后可能需要重新认证。
- **配置存在但启动失败：**检查日志中的认证、证书路径或权限错误；配置必须属于 Pro，文件名为 `tt5prosrv.xml`。
- **连不上或没有声音：**检查 TCP 和 UDP 是否都已映射、放行；启用加密时，客户端加密选项也要对应。
- **无法保存配置或上传文件：**检查目录写权限、存储路径和配额，迁移配置时更新容器内路径。

服务端功能、授权及证书配置请参见 [BearWare 官方网站](https://bearware.dk/) 和 [官方 Pro 服务端说明](https://github.com/BearWare/TeamTalk5/blob/master/Setup/Server/Linux/README_professional)。

---

## English

Maintained by hejd, this image runs the `tt5prosrv` TeamTalk Professional server distributed by BearWare. It supports `linux/amd64` and `linux/arm64`, encrypted connections, and BearWare WebLogin.

**If you already have a valid configuration and a usable BearWare WebLogin token, mount the configuration directory at `/etc/teamtalk` in the container and start the image. The startup command is already configured: no additional `command`, `entrypoint`, `-nd`, or `-wd` is needed.**

The configuration file is `tt5prosrv.xml`. Starting Pro requires a BearWare.dk WebLogin account authorized for use with the server. For a new installation, complete the setup and authentication steps below. The standard edition is available at [hejd/teamtalk](https://hub.docker.com/r/hejd/teamtalk).

### Existing configuration: start directly

Save the following as `compose.yaml`. Put your existing configuration in a `data` folder beside it, or change only `./data` on the left side of the volume mapping to your existing directory. Keep `/etc/teamtalk` on the right.

```yaml
services:
  teamtalkpro:
    image: hejd/teamtalkpro:latest
    container_name: teamtalkpro
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
  tt5prosrv.xml
  files/          # If file sharing is enabled
  server.crt      # If encryption is enabled; use your own certificate and filenames
  server.key
```

Run these commands from the directory containing `compose.yaml`:

```sh
docker compose up -d
docker compose logs --tail 100 teamtalkpro
```

Upload directories, certificates, and private key paths in an existing configuration must point to locations visible inside the container, such as `/etc/teamtalk/files` and `/etc/teamtalk/server.crt`. Use separate data directories for the standard and Pro editions.

With Docker Desktop, use Linux containers. Windows users can run these commands in PowerShell.

### First use: setup and BearWare authentication

Using the same `compose.yaml`, create the file storage directory and run the interactive setup wizard:

```sh
docker compose run --rm teamtalkpro mkdir -p /etc/teamtalk/files
docker compose run --rm -it teamtalkpro -wizard
```

Follow the wizard to configure the server name and user accounts:

- Keep both TCP and UDP ports at `10333` to match the mappings above.
- If you enable file sharing, enter `/etc/teamtalk/files` as the storage directory and set disk quotas.
- To create a username/password account, select `Create new user account` and choose your own credentials. Select `Administrator` if you need an administrator account.
- To enable encryption, first place your certificate and private key in the data directory, then enter their container paths in the wizard. Encryption must be enabled in the server configuration, and clients must also use encrypted connections.
- Confirm that you want to save the settings and look for `Changes saved.`.

Next, start the server once in an interactive foreground session to complete the required BearWare WebLogin authentication:

```sh
docker compose run --rm -it teamtalkpro
```

Enter your authorized BearWare account when prompted and agree to save the access token in the configuration file. Initial authentication requires access to the BearWare service. Once the server has started, press `Ctrl+C` to stop it normally, then start it in the background:

```sh
docker compose up -d
```

If you already authenticated in the wizard and saved a valid token, you can start in the background directly. The token is stored in `tt5prosrv.xml` in the mounted directory and reused on subsequent starts. Server authentication with BearWare and the client login accounts created in the wizard serve different purposes; configure each as needed.

### Connecting a client

In the TeamTalk client, enter your server address, TCP port `10333`, UDP port `10333`, and the configured account. If the server uses encryption, enable encryption in the client too. See the official documentation linked below for certificate verification.

For access over the internet, allow both TCP and UDP in the host firewall and any cloud security group. If the server is behind a router, configure port forwarding as well. When running alongside the standard edition, use different host ports: for example, change the Pro mappings to `10334:10333/tcp` and `10334:10333/udp`, then use `10334` in the client.

### Data, permissions, and maintenance

Keep mounting the same data directory to preserve the configuration, WebLogin token, certificates, and uploaded files. Back up the entire directory and protect the tokens and private keys it contains. View container logs with `docker compose logs`; whether the server also writes log files depends on its configuration.

Optional environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `TZ` | `Asia/Shanghai` | Container time zone |
| `uid` | `0` | Numeric UID used to run the server |
| `gid` | Same as `uid` | Numeric GID used to run the server |
| `chown` | `auto` | `auto` recursively sets ownership of the data directory when a nonzero UID or GID is specified; `true` always sets ownership; `false` leaves it unchanged |

To run the server as a non-root user, add the following under the service definition and replace the numbers as needed. Use the same UID/GID for the wizard, authentication, and background service:

```yaml
    environment:
      uid: "1000"
      gid: "1000"
```

Automatic ownership changes apply to the mounted host directory. If you use `chown: "false"` or Compose's `user:` setting, ensure that the selected user can read and write the configuration and files, and read the certificate and private key.

Stop the service before editing its configuration:

```sh
docker compose stop teamtalkpro
docker compose run --rm -it teamtalkpro -wizard
docker compose up -d
```

Before upgrading, stop the service and back up `data`. Then pull the latest image and recreate the container:

```sh
docker compose pull teamtalkpro
docker compose up -d teamtalkpro
```

The examples use `latest`, which points to the most recently published image in this repository. After a new release, run the pull and recreate commands above to upgrade without changing the image tag in your Compose file. To pin a specific version, choose a published version tag from the repository's [Tags page](https://hub.docker.com/r/hejd/teamtalkpro/tags).

### Troubleshooting

- **The background service repeatedly asks for BearWare login:** Stop it, then follow the interactive authentication steps above. Confirm that the token was saved in the same mounted directory. Changing your BearWare password may require authenticating again.
- **The configuration exists but startup fails:** Check the logs for authentication, certificate path, or permission errors. Use a Pro configuration named `tt5prosrv.xml`.
- **Cannot connect or no audio:** Check that both TCP and UDP are mapped and allowed. When encryption is enabled, the client encryption settings must match.
- **Cannot save settings or upload files:** Check write permissions, storage paths, and disk quotas. Update paths to their container locations when migrating a configuration.

For server features, authorization, and certificate setup, see the [BearWare website](https://bearware.dk/) and the [official Pro server documentation](https://github.com/BearWare/TeamTalk5/blob/master/Setup/Server/Linux/README_professional).

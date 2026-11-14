# A53 / honk Score 定制补丁

此目录是 Lemonade-22 的独立定制层。主分支中的 `dae/`、`daed/`、
`luci-app-daede/`、`ci/pins.env` 以及 kenzok8 的工作流均保持上游原样。
同步上游时不需要合并已展开的面板改动。新工作流在临时构建 checkout
应用 `patches/0001-luci-app-daede-honk-score.patch`，不把应用结果提交回来。
上游改动导致补丁不再兼容时，工作流在构建前明确报错，需要更新此补丁。

## 生成 APK

打开 Actions → **Build A53 APKs with honk Score** → Run workflow。
默认 SDK 为 `25.12.6`；也可填写已发布的更新稳定版，例如后续 `26.xx.x`。
不接受 24.10、IPK 或 snapshot。新增定制或同步上游软件包变更到 main
时也会自动构建。此工作流不修改上游 pins、不推送分支、不发布 Release，
不依赖 R2、PAT 或发布签名密钥。

成功后下载 `apks-openwrt-<版本>-aarch64_cortex-a53-honk-score`：

- `dae-*.apk`：沿用仓库冻结的 dae 源码与性能定制。
- `daed-*.apk`：沿用仓库冻结的 daed/dae-wing 源码。
- `honk-*.apk`：使用上游 OpenWrt 包配方，从锁定的 honk 源码编译。
- `luci-app-daede-*.apk`：应用 Score 补丁后的面板，版本号加 `_p1`（例如 `1.15_p1-r13`）。apk 的 `-r` 段只接受纯数字，后缀只认 `_alpha/_beta/_pre/_rc/_cvs/_svn/_git/_hg/_p`，写 `13.honk1` 或 `13_h` 都会被判为非法版本。
- `SHA256SUMS`、构建输入记录和 honk 包元数据。

dae/daed/LuCI 复用 kenzok8 的 SDK action、ImmortalWrt 对应大版本 SDK
及 Go 1.27；honk 复用 daeuniverse 的源码包配方、官方 OpenWrt 精确版本
SDK、源码固定的 Rust stable/nightly 和 bpf-linker。两个构建并行，最后
只有四个包全部存在才生成合并产物。失败日志单独保留，不把部分成功
视为完整包集。SDK、honk 和包配方版本记录在 `pins.env` 或构建记录中。

## 使用与范围

面板不再依赖或自动安装 daed，也不强制捆绑其他内核。使用 honk 时只需
安装 honk 和 luci-app-daede；dae、daed 仍作为独立可选 APK 构建，
面板保留对已安装后端的切换与管理。

安装包只面向 `aarch64_cortex-a53`、OpenWrt/ImmortalWrt 25.12 及之后
的相应环境；LuCI 本身是 noarch。较新主版本仍以对应 SDK、依赖和实际
固件兼容性为准，填写版本号不会让旧包自动兼容所有未来版本。

四个包的依赖仍由系统软件源提供。这里不生成可跨机型通用的 BTF 或
内核模块；无内核内置 BTF 时，需要与实际设备内核匹配的 BTF 包。
构建产物没有发布签名，手动本地安装使用 `apk add --allow-untrusted`，
并先按 `SHA256SUMS` 核对下载文件。不要同时运行 dae、daed、honk。

在 LuCI 配置页切换到 **honk**，配置节点或 HTTP(S) 订阅，在高级设置
的节点组策略选择 **综合评分（score）**，再保存并启动。面板只提供策略
选择，评分和选路由 honk 完成，不增加评分展示。截图中的 daed 内嵌
编辑器继续管理 daed。honk 使用独立 UCI、file 存储和生成配置
`/etc/honk/daede.dae`；运行中先校验配置，再等待真实 reload 结果。

## 维护

更新 honk 时同步修改 `HONK_COMMIT`、`HONK_GIT_TAG` 和 `HONK_VERSION`；
更新上游 OpenWrt 包配方时修改 `HONK_FEED_COMMIT`。引擎自己的 Rust、
doona 和 bpf-linker 版本由该 honk 源码提交决定。不会自动追踪不经审核
的 honk main，也不会改动 kenzok8 的自动同步和候选发布链。

手动检查补丁：在干净的本仓库 checkout 执行
`bash custom/honk-score/apply.sh`。这会修改该本地 checkout。
应用后可执行 `python3 scripts/honk-score-selftest.py`，需要 Linux、
Node.js、curl、ucode。已有保存链路测试与 honk beta.6 的模拟 eBPF
配置/重载验证；真实透明转发仍需设备验证。

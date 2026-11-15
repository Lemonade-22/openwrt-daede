# daede + honk Score 定制层

此目录是 Lemonade-22 的独立定制层。仓库中的上游 `dae/`、`daed/`、
`luci-app-daede/`、`ci/pins.env` 和 kenzok8 的自动同步工作流保持原样。

构建时在临时 checkout 应用两份补丁：

- `patches/0001-luci-app-daede-honk-score.patch`：LuCI 后端切换、honk
  面板账号、同源 API 中继、共享订阅导入、服务与备份支持。
- `webui-patches/0001-daede-webui-honk-native.patch`：让原 daed WebUI
  通过 honk Native API 管理节点、订阅和节点组，并提供实际生效的
  `score` 策略。

上游变化导致补丁不匹配时，构建会明确失败，需要更新补丁。已应用的
结果不会写回或提交到上游源码目录。

## 生成 APK

打开 Actions → **Build A53 APKs with honk Score** → Run workflow。
默认 SDK 为 `25.12.6`，也可填写已发布的更新稳定版，例如后续
`26.xx.x`。不接受 24.10、IPK 或 snapshot。

成功后下载 `apks-openwrt-<版本>-aarch64_cortex-a53-honk-score`：

- `dae-*.apk`：沿用仓库冻结的 dae 源码与性能定制。
- `daed-*.apk`：沿用仓库冻结的 daed/dae-wing 源码。
- `honk-*.apk`：使用上游 OpenWrt 配方，从锁定的 honk 源码编译。
- `luci-app-daede-*.apk`：包含 honk 版原 WebUI、LuCI 面板账号设置和
  共用订阅页；版本后缀为 `_p2`。
- `SHA256SUMS`、构建输入记录和 honk 包元数据。

dae/daed/LuCI 复用 kenzok8 的 SDK action、ImmortalWrt 对应大版本 SDK
及 Go 1.27；honk 复用 daeuniverse 的源码包配方、官方 OpenWrt 精确
版本 SDK、固定 Rust stable/nightly 和 bpf-linker。两个构建并行，最后
只有四个包全部存在才生成合并产物。

WebUI 在构建期间从固定 DAED_COMMIT 重新生成，不在仓库提交静态产物。
构建会执行类型检查、前端测试和 `VITE_HONK=1` 生产构建，再装入
`luci-app-daede` 的 `/www/daede-honk/`。

## 使用

安装 honk 和 luci-app-daede 后可只使用 honk，不要求运行 daed；dae、
daed 仍是独立的可选 APK。不要同时运行 dae、daed、honk。

在 LuCI 的 daede 页面切换到 honk，设置面板账号和密码，然后打开
WebUI。首次使用会把该账号初始化为 honk 管理员；已有账号必须填写
它当前的密码，保存密码不会重置账号。

honk API 只监听 `127.0.0.1:9528`，WebUI 通过同一个 uhttpd 下的
`/cgi-bin/daede-honk` 中继访问，不在 URL 中传递令牌。首次管理员设置
不经过远程 CGI。

节点、订阅和群组在 WebUI 中管理。群组策略下拉框中的 `score` 由
honk 实际执行，不增加评分数值或排行展示。订阅转换页与 daed 共用，
目标选择 honk 后会生成或更新 provider，并绑定到 `proxy` 群组。

LuCI 不再生成 honk 的节点、DNS、路由和群组表单，避免两套编辑器互相
覆盖。设置 honk 监听器时只替换 `native_api` 块，其他配置保留；修改前
会留下 `.pre-webui` 备份。

## 构建兼容性与安装

产物面向 `aarch64_cortex-a53`、OpenWrt/ImmortalWrt 25.12 及之后的
相应环境；LuCI 包本身是 noarch。较新的主版本仍以对应 SDK、依赖和
实际固件兼容性为准。

四个包的依赖由系统软件源提供。这里不生成可跨机型的通用 BTF 或内核
模块；没有内核内置 BTF 时，需要与实际设备匹配的 BTF 包。构建产物
没有发布签名，本地安装使用 `apk add --allow-untrusted`，并先按
`SHA256SUMS` 核对下载文件。

## 维护与验证

更新 honk 时同步修改 `HONK_COMMIT`、`HONK_GIT_TAG`、`HONK_VERSION`
和 `HONK_FEED_COMMIT`；更新 WebUI 基线时修改 `WEBUI_COMMIT`。

在干净 checkout 手动检查 LuCI 补丁：

```sh
bash custom/honk-score/apply.sh <clean-checkout>
```

WebUI 补丁从锁定的 daed 提交应用，具体步骤见
`custom/honk-score/build-webui.sh`。已有类型检查、前端单元测试、真实
honk beta.6 mock-eBPF API 测试和浏览器渲染验证；真实设备上的透明代理
转发、score 选路及升级恢复仍需在目标路由器验证。

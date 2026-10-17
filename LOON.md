# Loon 插件（ddgksf2013）

本仓库将 `ddgksf2013/Rewrite` 中的配置模板转换为 Loon 插件格式，存放于 `Loon/` 目录。

- 上游仓库：https://github.com/ddgksf2013/Rewrite
- 作者：ddgksf2013（墨鱼手记）
- 格式：Loon plugin（`.lpx`）
- 清单：`index.json`

## 使用

用 Loon 打开对应的 `.lpx` 原始链接即可导入：

```
https://raw.githubusercontent.com/wfordawn/Rewrite/master/Loon/<分类>/<文件名>.lpx
```

## 目录

- `Loon/AdBlock/` — 应用去广告
- `Loon/Function/` — 功能增强
- `Loon/Html/` — 网页增强
- `Loon/UnlockVip/` — VIP 解锁

## 说明

- 插件内容由上游配置转换而来，版权归原作者所有，请遵守上游许可与使用条款。
- 上游更新后需重新转换，本目录不会自动同步。

## 脚本依赖

插件引用的 JS 脚本已镜像到 `Loon/Scripts/`，`script-path` 均指向本仓库，不再依赖原作者仓库。

少数上游已删除的脚本仍指向原始地址（上游本身已 404）：
- `bilibili_json.js`（BilibiliAds / BilibiliAdsLite）
- `redbook_json.js`（XiaoHongShuAds）
- `baiduCloud.adblock.js`（BaiduCloud）
- `suishouji.js`（SuiShouJi，MoYu 仓库已不可用）

相关插件功能可能不完整，可关注上游是否补回。

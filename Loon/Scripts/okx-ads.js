// OKX 首页运营卡片去广告
// 命中：/priapi/v3/growth/mobile/card/pro/home-page
// 处理：丢弃首页推荐位运营卡（活动、拉新、交易赛），保留信息类卡片

const url = $request.url;
if (!$response.body) $done({});
let obj = JSON.parse($response.body);

// 这些 uniqueName 为信息/安全类卡片，保留
const KEEP = ["nologinpor", "nologinporessential", "safeguard"];

if (obj?.data && Array.isArray(obj.data.cards)) {
  obj.data.cards = obj.data.cards.filter((card) => {
    const name = (card?.uniqueName || "").toLowerCase();
    const scene = (card?.analytics?.trackingProperties || []).find(
      (p) => p?.propertyName === "scene_id"
    )?.propertyValue;
    // 只处理首页推荐场景的卡片
    if (scene !== "homepage_card_rcmd") return true;
    if (KEEP.some((k) => name.includes(k))) return true;
    // category 1/2 为活动运营位
    const cat = String(card?.analytics?.category ?? "");
    return !["1", "2"].includes(cat);
  });
  delete obj.data.lists;
  delete obj.data.banners;
}

$done({ body: JSON.stringify(obj) });

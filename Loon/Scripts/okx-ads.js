// OKX 首页运营卡片去广告
// 命中：/priapi/v3/growth/mobile/card/pro/home-page
// 处理：清空 data.cards，移除活动、推广、拉新卡片

const url = $request.url;
if (!$response.body) $done({});
let obj = JSON.parse($response.body);

if (obj?.data) {
  if (Array.isArray(obj.data.cards)) obj.data.cards = [];
  delete obj.data.lists;
  delete obj.data.banners;
}

$done({ body: JSON.stringify(obj) });

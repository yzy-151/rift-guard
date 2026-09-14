import fs from "node:fs/promises";

const path = "game/data/v2/cards.json";
const cards = JSON.parse(await fs.readFile(path, "utf8"));
const copy = {
  traveler_special_epic: ["剑术扩展", "旅行者：普攻获得大范围顺劈。"],
  traveler_signature_legendary: ["命之座共鸣", "旅行者：攻击力提高35%，攻击速度提高20%。"],
  hero_02_special_epic: ["烟火轮舞", "宵宫：每次攻击额外发射1枚火矢。"],
  hero_02_signature_legendary: ["琉金云间草", "宵宫：额外发射2枚火矢，命中产生范围爆炸。"],
  hero_03_special_epic: ["万众狂欢", "芙宁娜：每次治疗量提高18。"],
  hero_03_signature_legendary: ["众水的颂诗", "芙宁娜：攻击追加48%回响伤害，治疗量提高26。"],
  hero_04_special_epic: ["星斗归位", "刻晴：雷击额外弹射2名敌人。"],
  hero_04_signature_legendary: ["雷楔风暴", "刻晴：雷击额外弹射4名敌人，攻击速度提高28%。"],
  hero_05_special_epic: ["霜华矢", "甘雨：箭矢附带减速并产生72范围冰爆。"],
  hero_05_signature_legendary: ["麒麟巡游", "甘雨：冰爆范围扩大至125，攻击力提高42%。"],
  hero_06_special_epic: ["高天之歌", "温迪：箭矢额外穿透2名敌人。"],
  hero_06_signature_legendary: ["风神之诗", "温迪：额外发射1枚箭矢并穿透4名敌人。"],
  hero_07_special_epic: ["地心", "钟离：普攻获得顺劈，防御提高28。"],
  hero_07_signature_legendary: ["天星", "钟离：顺劈伤害提升至100%，最大生命提高55%。"],
  hero_08_special_epic: ["云吟乍涌", "白露：治疗间隔缩短28%。"],
  hero_08_signature_legendary: ["持明医术", "白露：治疗量提高48，治疗间隔再缩短38%。"],
};
for (const card of cards) {
  if (copy[card.id]) [card.name, card.description] = copy[card.id];
}
await fs.writeFile(path, JSON.stringify(cards, null, 2) + "\n", "utf8");

const mechanicPath = "game/data/v2/mechanic_cards.json";
const mechanics = JSON.parse(await fs.readFile(mechanicPath, "utf8"));
for (const card of mechanics) {
  if (card.id === "reinforcement_pyro") {
    card.name = "增援·宵宫";
    card.description = "若队伍未满，宵宫立即加入本关并自动作战。";
  } else if (card.id === "reinforcement_hydro") {
    card.name = "增援·芙宁娜";
    card.description = "若队伍未满，芙宁娜立即加入本关并自动作战。";
  }
}
await fs.writeFile(mechanicPath, JSON.stringify(mechanics, null, 2) + "\n", "utf8");

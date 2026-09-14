import fs from "node:fs/promises";
import path from "node:path";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const projectRoot = path.resolve(process.cwd());
const inputPath = path.join(projectRoot, "content", "game_config.xlsx");
const previewDir = path.join(projectRoot, "docs", "v7-validation");
const workbook = await SpreadsheetFile.importXlsx(await FileBlob.load(inputPath));

if (process.argv[2] === "inspect") {
  const summary = await workbook.inspect({ kind: "workbook,sheet,table", maxChars: 6000, tableMaxRows: 8, tableMaxCols: 18 });
  console.log(summary.ndjson);
  await fs.mkdir(previewDir, { recursive: true });
  for (const name of ["对话", "图片资源", "UI"]) {
    const preview = await workbook.render({ sheetName: name, autoCrop: "all", scale: 1, format: "png" });
    await fs.writeFile(path.join(previewDir, `excel-before-${name}.png`), new Uint8Array(await preview.arrayBuffer()));
  }
  process.exit(0);
}

const ui = workbook.worksheets.getItem("UI");
const rows = [
  ["stage_button", 400, 8, 156, 36, "", "stretch", "关卡  [F4]", 14, 0, 0, 0, 0, "战斗顶部关卡入口", 1],
  ["squad_button", 570, 8, 156, 36, "", "stretch", "编队  [F3]", 14, 0, 0, 0, 0, "战斗顶部编队入口", 1],
  ["squad_background", 0, 0, 1280, 720, "ui.bg.archive", "stretch", "", 0, 0, 0, 0, 0, "编队页背景", 1],
  ["squad_frame", 72, 42, 1136, 636, "", "stretch", "", 0, 0, 0, 0, 0, "编队页主框", 1],
  ["squad_title", 36, 50, 700, 42, "", "stretch", "", 30, 0, 0, 0, 0, "下一关标题", 1],
  ["squad_subtitle", 36, 94, 900, 24, "", "stretch", "", 14, 0, 0, 0, 0, "解锁提示", 1],
  ["squad_confirm", 308, 500, 520, 54, "", "stretch", "确认编队并进入下一关   →", 18, 0, 0, 0, 0, "确认按钮", 1],
  ...Array.from({ length: 8 }, (_, i) => [
    `squad_character_${i + 1}`, 36 + (i % 4) * 268, 142 + Math.floor(i / 4) * 156, 250, 132,
    "", "stretch", "", 0, 0, 0, 0, 0, `角色槽位 ${i + 1}`, 1,
  ]),
  ["stage_background", 0, 0, 1280, 720, "", "stretch", "", 0, 0, 0, 0, 0, "关卡选择背景", 1],
  ["stage_frame", 72, 64, 1136, 592, "", "stretch", "", 0, 0, 0, 0, 0, "关卡选择主框", 1],
  ["stage_title", 38, 52, 700, 43, "", "stretch", "选择作战区域", 30, 0, 0, 0, 0, "关卡选择标题", 1],
  ["stage_card_1", 38, 150, 330, 310, "", "stretch", "", 0, 0, 0, 0, 0, "第一关卡片", 1],
  ["stage_card_2", 392, 150, 330, 310, "", "stretch", "", 0, 0, 0, 0, 0, "第二关卡片", 1],
  ["stage_card_3", 746, 150, 330, 310, "", "stretch", "", 0, 0, 0, 0, 0, "第三关卡片", 1],
];
ui.getRange(`A26:O${25 + rows.length}`).values = rows;
const added = ui.getRange(`A26:O${25 + rows.length}`);
added.format.font = { name: "Microsoft YaHei", size: 10, color: "#2A2024" };
added.format.verticalAlignment = "center";
added.format.wrapText = true;
ui.getRange(`A26:A${25 + rows.length}`).format.font = { name: "Microsoft YaHei", size: 10, bold: true, color: "#7D2436" };
ui.getRange(`B26:E${25 + rows.length}`).format.numberFormat = "0";
ui.getRange(`I26:O${25 + rows.length}`).format.numberFormat = "0";

const dialogue = workbook.worksheets.getItem("对话");
const mode1Rows = [
  [1,"mode1_opening",1,"旅行者","裂隙已经越过警戒线。元素尚未回应我，但剑还在手里。","saria","left",115,75,1,0,"jessica","right",685,80,1,0,"main"],
  [1,"mode1_opening",2,"通讯员","水晶会收集敌人的残响。每次升级都能改写攻击方式，弹道与支援也会随构筑增长。","jessica","left",115,75,1,0,"saria","right",685,80,1,0,"main"],
  [1,"mode1_opening",3,"旅行者","那就从这里开始。守住五分半，把右侧涌来的东西全部送回去。","saria-soft","left",115,75,1,0,"jessica","right",685,80,1,0,"main"],
  [1,"mode1_won",1,"旅行者","第一道裂隙关闭了。水晶记录下了这次构筑，下一关会有新的同伴回应。","saria-soft","left",115,75,1,0,"jessica","right",685,80,1,0,"main"],
  [1,"mode1_stage2_opening",1,"宵宫","通讯接通。第二道裂隙已经变成赤潮，我从高台提供火力。","jessica","left",115,75,1,0,"saria","right",685,80,1,0,"main"],
  [1,"mode1_stage2_opening",2,"旅行者","上一关的强化已经消散，但元素选择和新的构筑会再次回应。两个人守住三条路线。","saria-soft","left",115,75,1,0,"jessica","right",685,80,1,0,"main"],
  [1,"mode1_stage3_opening",1,"芙宁娜","第三道裂隙已经结晶化，路线正在上下错位。水域会替大家维持生命。","muelsyse","left",115,75,1,0,"jessica","right",685,80,1,0,"main"],
  [1,"mode1_stage3_opening",2,"宵宫","黑曜母巢会周期召来疾行兽，我负责清掉它的护卫。","jessica","left",115,75,1,0,"muelsyse","right",685,80,1,0,"main"],
  [1,"mode1_stage3_opening",3,"旅行者","三人到齐。重新选择元素与构筑，把母巢留在这里。","saria-soft","left",115,75,1,0,"muelsyse","right",685,80,1,0,"main"],
  [1,"mode1_final_won",1,"芙宁娜","黑曜母巢停止活动，三道裂隙都已经安静下来。","muelsyse","left",115,75,1,0,"saria","right",685,80,1,0,"main"],
  [1,"mode1_final_won",2,"旅行者","模式一的防线全部守住，水晶已经记录新的角色与卡牌。","saria-soft","left",115,75,1,0,"muelsyse","right",685,80,1,0,"main"],
  [1,"mode1_lost",1,"旅行者","水晶破碎前保住了核心记录。重来一次，这次把弹道铺满整条路线。","saria","left",115,75,1,0,"jessica","right",685,80,1,0,"main"],
];
dialogue.getRange("A22:R33").values = mode1Rows;
dialogue.getRange("A22:R33").format.fill = "#FFF4CF";
dialogue.getRange("A22:R33").format.font = { name: "Microsoft YaHei", size: 10, color: "#2A2024" };
dialogue.getRange("A22:R33").format.wrapText = true;
const usedDialogue = dialogue.getUsedRange();
const startRow = Math.max(usedDialogue.rowCount + 1, 40);
dialogue.getRange(`A${startRow}:R${startRow + 19}`).clear({ applyTo: "contents" });
dialogue.getRange(`A${startRow}:R${startRow + 19}`).format.fill = "#FFF4CF";
dialogue.getRange(`A${startRow}:R${startRow + 19}`).format.borders = { preset: "outside", style: "thin", color: "#D5B45A" };
dialogue.getRange(`E${startRow}:E${startRow + 19}`).format.columnWidth = 46;

const assets = workbook.worksheets.getItem("图片资源");
assets.getRange("A11:D11").values = [["ui.bg.archive", "res://assets/helltaker/backgrounds/chapterBG0008.png", "编队与图鉴背景", "UI背景"]];
assets.getRange("A11:D11").format.fill = "#FFF4CF";
assets.getRange("A11:D11").format.font = { name: "Microsoft YaHei", size: 10, color: "#2A2024" };

const guide = workbook.worksheets.getItem("使用说明");
guide.getRange("A25:B27").values = [
  ["模式一剧情", "段落名可填写mode1_opening、mode1_won、mode1_stage2_opening、mode1_stage3_opening、mode1_final_won、mode1_lost。"],
  ["编队界面", "UI表的squad_开头控件可修改位置、尺寸、文字和素材；游戏中按F3打开编队。"],
  ["关卡选择", "UI表的stage_开头控件可修改关卡入口与选择页；游戏中按F4打开已解锁地图。"],
];
guide.getRange("A25:B27").format.font = { name: "Microsoft YaHei", size: 10, color: "#2A2024" };
guide.getRange("A25:A27").format.font = { name: "Microsoft YaHei", size: 10, bold: true, color: "#7D2436" };
guide.getRange("A25:B27").format.wrapText = true;

await fs.mkdir(previewDir, { recursive: true });
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(inputPath);
const uiPreview = await workbook.render({ sheetName: "UI", range: `A1:O${25 + rows.length}`, scale: 1, format: "png" });
await fs.writeFile(path.join(previewDir, "excel-v7-ui.png"), new Uint8Array(await uiPreview.arrayBuffer()));
const inspect = await workbook.inspect({ kind: "table", range: `UI!A21:O${25 + rows.length}`, include: "values,formulas", tableMaxRows: 20, tableMaxCols: 15 });
console.log(inspect.ndjson);
const errors = await workbook.inspect({ kind: "match", searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!", options: { useRegex: true, maxResults: 300 }, summary: "final formula error scan" });
console.log(errors.ndjson);

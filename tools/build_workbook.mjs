import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Workbook, SpreadsheetFile } from '@oai/artifact-tool';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const out = path.join(root, 'outputs/m5');
const story = JSON.parse(await fs.readFile(path.join(root, 'game/data/story.json'), 'utf8'));
const uiRows = JSON.parse(await fs.readFile(path.join(root, 'tools/m5_ui_rows.json'), 'utf8'));
const wb = Workbook.create();
function setup(name, title, subtitle, headers, widths, lastRow) {
  const s = wb.worksheets.add(name), end = String.fromCharCode(64 + headers.length);
  s.showGridLines = false;
  s.getRange(`A1:${end}${lastRow}`).format = {font:{name:'Microsoft YaHei',size:11,color:'#263443'},verticalAlignment:'center',rowHeight:30};
  s.getRange('A1').values = [[title]];
  s.getRange('A1').format.font = {name:'Microsoft YaHei',size:17,bold:true,color:'#263443'};
  s.getRange(`A1:${end}1`).format.rowHeight = 36;
  s.getRange(`A1:${end}1`).format.borders = {bottom:{style:'thin',color:'#BCC8D0'}};
  s.getRange('A2').values = [[subtitle]];
  s.getRange(`A2:${end}2`).format.font = {name:'Microsoft YaHei',size:10,color:'#536578'};
  s.getRange(`A4:${end}4`).values = [headers];
  s.getRange(`A4:${end}4`).format = {fill:'#33485C',font:{name:'Microsoft YaHei',size:11,bold:true,color:'#FFFFFF'},horizontalAlignment:'center',rowHeight:32};
  widths.forEach((width,i)=>{s.getRange(`${String.fromCharCode(65+i)}1:${String.fromCharCode(65+i)}${lastRow}`).format.columnWidthPx=width;});
  if(name!=='使用说明') {
    s.getRange(`A5:${end}${lastRow}`).format.fill='#FFF8DE';
    s.freezePanes.freezeRows(4);
    s.freezePanes.freezeColumns(name==='对话'?4:1);
  }
  return s;
}
const instructions = [
  ['开始编辑','修改content/game_config.xlsx；浅黄色区域为输入区，白色区域为说明。'],
  ['应用修改','保存并关闭Excel，再重新启动游戏；不支持热更新。'],
  ['表头与格式','表头固定在第4行，从第5行填数据；不要改表名、列名或列顺序，不要填写公式。'],
  ['对话启用','启用填1加载、0禁用；空启用行和空对白行忽略，预留到第504行。'],
  ['段落与顺序','内置段落opening、node1、node2、node3、node4、won、lost；每段顺序从1开始。'],
  ['新增段落','在对话表填写新的段落名并按顺序添加台词；重启后按F6选择预览。'],
  ['立绘引用','主图、配图填写图片资源表中的资源名；新增图片先登记资源名和文件。'],
  ['立绘坐标','X/Y是1280×720逻辑画布中显示框左上角；主图默认115/75，配图685/80。'],
  ['侧与X优先级','主X/配X非空时优先使用绝对坐标；留空才由left/right决定默认X为115/685。'],
  ['缩放与翻转','主图显示框520×665，配图490×650；缩放1为原框，翻转填0或1。'],
  ['高亮','主侧、配侧填left或right；高亮填main、partner或none。'],
  ['外部图片','图片放到content/images内，文件列填images/xxx.png；内置图片使用res://路径。'],
  ['UI位置与尺寸','编辑控件ID对应的X/Y、宽/高；menu_frame坐标相对菜单容器，其余按1280×720。'],
  ['UI素材与模式','素材填写资源名；ninepatch为九宫格，stretch为拉伸，keep保留默认显示方式。'],
  ['UI边距与文字','九宫格边距按原图像素填写；姓名、正文和动态按钮文字由游戏提供，见UI说明列。'],
  ['UI启用','UI启用1应用该行、0忽略该行；空行不加载，控件ID需使用模板中的已有ID。'],
  ['特效预览','游戏中按F7打开特效预览。'],
  ['错误处理','异常数据会明确报错并拒绝应用整份Excel；修正后保存、关闭并重启游戏。'],
  ['数据来源','初始对白取自游戏story.json；UI数值与当前游戏控件默认位置一致。'],
];
const guide=setup('使用说明','裂隙守望配置','编辑对白、立绘与界面位置',['项目','填写说明'],[155,835],23);
guide.getRange('A5:B23').values=instructions;
guide.getRange('B5:B23').format.wrapText=true;
guide.getRange('A5:A23').format.font.bold=true;
guide.getRange('A5:B23').format.rowHeight=45;
const dialog=setup('对话','对白与立绘','浅黄色可编辑；保存关闭Excel后重启；详细规则见使用说明',['启用','段落','顺序','姓名','对白','主图','主侧','主X','主Y','主缩放','主翻转','配图','配侧','配X','配Y','配缩放','配翻转','高亮'],[58,100,62,95,525,115,80,72,72,82,82,115,80,72,72,82,82,100],504);
const dialogRows=Object.entries(story).flatMap(([section,lines])=>lines.map(([portrait,name,line],i)=>[1,section,i+1,name,line,portrait,'left',115,75,1,0,portrait.startsWith('saria')?'muelsyse':'saria','right',685,80,1,0,'main']));
dialog.getRange(`A5:R${dialogRows.length+4}`).values=dialogRows;
dialog.getRange(`A5:R${dialogRows.length+4}`).format.rowHeight=55;
dialog.getRange('E5:E504').format.wrapText=true;
for(const c of ['A','C','H','I','K','N','O','Q']) dialog.getRange(`${c}5:${c}504`).setNumberFormat('0');
for(const c of ['J','P']) dialog.getRange(`${c}5:${c}504`).setNumberFormat('0.00');
for(const c of ['A','K','Q']) dialog.getRange(`${c}5:${c}504`).dataValidation={rule:{type:'list',values:['0','1']}};
for(const c of ['G','M']) dialog.getRange(`${c}5:${c}504`).dataValidation={rule:{type:'list',values:['left','right']}};
dialog.getRange('R5:R504').dataValidation={rule:{type:'list',values:['main','partner','none']}};
const resources=setup('图片资源','图片资源','外部图片放入content/images；对白和UI通过资源名引用',['资源名','文件','说明','用途'],[135,505,265,160],104);
const resourceRows=[
  ['saria','res://assets/portraits/saria.png','塞雷娅默认立绘','主图 / 配图'],
  ['saria-soft','res://assets/portraits/saria-soft.png','塞雷娅柔和表情','主图 / 配图'],
  ['jessica','res://assets/portraits/jessica.png','杰西卡立绘','主图 / 配图'],
  ['muelsyse','res://assets/portraits/muelsyse.png','缪尔赛斯立绘','主图 / 配图'],
  ['dialog_frame','res://assets/gothic/panel_main_horned.png','对话和菜单外框','UI九宫格'],
  ['tab_frame','res://assets/gothic/tab_trident.png','页签边框','UI素材'],
];
resources.getRange('A5:D10').values=resourceRows;
const ui=setup('UI','界面位置与素材','坐标按1280×720填写；menu_frame相对菜单容器；启用1应用、0忽略',['控件ID','X','Y','宽','高','素材','模式','文字','字号','边距左','边距上','边距右','边距下','说明','启用'],[170,65,65,65,65,125,105,210,65,75,75,75,75,340,60],154);
ui.getRange(`A5:O${uiRows.length+4}`).values=uiRows;
ui.getRange(`A5:O${uiRows.length+4}`).format.rowHeight=45;
ui.getRange('H5:H154').format.wrapText=true;
ui.getRange('N5:N154').format.wrapText=true;
for(const c of ['B','C','D','E','I','J','K','L','M','O']) ui.getRange(`${c}5:${c}154`).setNumberFormat('0');
ui.getRange('G5:G154').dataValidation={rule:{type:'list',values:['ninepatch','stretch','keep']}};
ui.getRange('O5:O154').dataValidation={rule:{type:'list',values:['0','1']}};
await fs.mkdir(out,{recursive:true});
for(const [sheetName,range,filename] of [['使用说明','A1:B23','guide'],['对话','A4:F12','dialog_text'],['对话','G4:R12','dialog_positions'],['图片资源','A1:D11','resources'],['UI','A4:G14','ui_positions'],['UI','H4:O14','ui_text']]) {
  const preview=await wb.render({sheetName,range,scale:1.5,format:'png'});
  await fs.writeFile(path.join(out,`${filename}.png`),new Uint8Array(await preview.arrayBuffer()));
}
const summary=await wb.inspect({kind:'table',range:'对话!A4:R8',include:'values,formulas',tableMaxRows:5,tableMaxCols:18,maxChars:2500});
const errors=await wb.inspect({kind:'match',searchTerm:'#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!',options:{useRegex:true,maxResults:20},maxChars:1500});
await fs.writeFile(path.join(out,'workbook_check.txt'),`${summary.ndjson}\n${errors.ndjson}\nDialogue rows: ${dialogRows.length}; UI rows: ${uiRows.length}; resource rows: ${resourceRows.length}\n`);
const xlsx=await SpreadsheetFile.exportXlsx(wb);
await xlsx.save(path.join(out,'game_config.xlsx'));
await fs.mkdir(path.join(root,'content'),{recursive:true});
await fs.copyFile(path.join(out,'game_config.xlsx'),path.join(root,'content/game_config.xlsx'));
console.log(JSON.stringify({output:path.join(out,'game_config.xlsx'),dialogues:dialogRows.length,ui:uiRows.length,resources:resourceRows.length,errors:errors.ndjson}));

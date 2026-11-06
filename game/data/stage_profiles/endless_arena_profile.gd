extends RefCounted
## Shared world geometry for simulation, expedition destinations and map artwork.
const ARENA := Rect2(80,80,2560,1600)
const HUB := Vector2(1360,880)
const HUB_AREA := Rect2(1080,640,560,480)
const DISTRICTS := [
	{"id":"observatory","name":"北境观测站","center":Vector2(680,480),"area":Rect2(420,300,520,360),"role":"驻守信标","color":"#7aaeb8"},
	{"id":"foundry","name":"赤铜兵工厂","center":Vector2(2040,480),"area":Rect2(1780,300,520,360),"role":"压制远程","color":"#be876a"},
	{"id":"supply","name":"暮色补给营","center":Vector2(680,1280),"area":Rect2(420,1100,520,360),"role":"回收与医疗","color":"#91b39a"},
	{"id":"archive","name":"旧城档案馆","center":Vector2(2040,1280),"area":Rect2(1780,1100,520,360),"role":"巡查路线","color":"#afa1c4"},
]
const CORRIDORS := [
	Rect2(420,440,1880,160),Rect2(420,1160,1880,160),
	Rect2(1240,300,240,1160),Rect2(580,380,200,1040),Rect2(1940,380,200,1040),
]
const COVERS := [
	Rect2(440,300,180,56),Rect2(420,550,56,160),
	Rect2(2100,300,180,56),Rect2(2244,550,56,160),
	Rect2(440,1404,180,56),Rect2(420,1040,56,160),
	Rect2(2100,1404,180,56),Rect2(2244,1040,56,160),
]
const MEDBAY := Vector2(680,1280)
const MEDBAY_HOLD_SECONDS := 5.0
const MEDBAY_COOLDOWN := 90.0
const MEDBAY_HEAL_RATIO := .20
const MEDBAY_RADIUS := 150.0
const ZONE_CENTERS := [HUB,Vector2(1760,680),Vector2(1760,1080),Vector2(960,1080),Vector2(960,680)]

# Godot 技术方案（文字弹反节奏战）- 修订版

> 基于 `assets/修改说明.md`：关卡 JSON 配置、按波次与节拍生成、每拍音效。

---

## 一、修订要点

1. **关卡设计**：敌人分多波攻击（如 5 波），每波由 JSON 配置。
2. **节拍驱动**：游戏时间按节拍划分，节拍速度可配置，**每拍播放** `assets/music/tap.wav`。
3. **每波配置**：攻击字表、反击字表、每字伤害、每字出现节拍、波次间隔节拍。

---

## 二、关卡 JSON 格式

```json
{
  "beat_bpm": 120,
  "waves": [
    {
      "attack_words": ["你", "好", "笨"],
      "counterattack_words": ["你", "才", "笨"],
      "damage_value": [1, 1, 1],
      "beat_config": [1, 2, 4],
      "interval_time": 15
    }
  ]
}
```

- **beat_bpm**：节拍速度（每分钟多少拍），可选，默认 120。
- **waves**：波次数组。每项为一次攻击：
  - **attack_words**：本波攻击字列表（显示给玩家弹反）。
  - **counterattack_words**：弹反后飞回敌人的字列表，与 attack_words 按 index 对应。
  - **damage_value**：每个字弹回命中敌人时的伤害，与 attack_words 按 index 对应。
  - **beat_config**：每个字在本波「开始的第几个节拍」出现（从 1 起算）。如 `[1,2,4]` 表示第 1、2、4 拍各出一个字。
  - **interval_time**：本波攻击结束后，间隔多少拍再开始下一波。

示例：上述配置表示在第 1、2、4 拍发射「你」「好」「笨」；弹反后变为「你」「才」「笨」，伤害均为 1；本波结束后间隔 15 拍再开始下一波。

---

## 三、整体架构（与现有一致，数据源改为关卡）

| 场景/节点 | 职责 |
|-----------|------|
| **Main** | 加载关卡 JSON；节拍 Timer + 每拍播放 tap.wav；按当前波次与 beat_config 在对应节拍生成 FlyingText；波次推进（interval_time）与胜负判定。 |
| **GamePlay** | 游戏层容器：Player、Enemy、FlyingText 父节点。 |
| **Player** | 不变：弹反区、输入检测。 |
| **Enemy** | 不变：血量、受击；伤害值改为由 FlyingText 提供（每字不同）。 |
| **FlyingText** | 初始化参数改为：spawn_pos, attack_word, counter_word, damage；弹反后显示 counter_word，命中敌人时造成 damage。 |
| **HUD** | 不变：血条、胜负界面。 |

---

## 四、核心系统修订

### 4.1 节拍与音效

- **Timer**：按 `60 / beat_bpm` 秒每拍触发一次。
- **每拍**：先播放 `res://assets/music/tap.wav`，再执行「当前拍」逻辑（生成字、推进波次等）。

### 4.2 波次与生成

- **全局节拍**：从 0 开始递增的 beat_index。
- **当前波**：current_wave_index、本波起始节拍 wave_start_beat。
- **本波内相对拍**：beat_in_wave = beat_index - wave_start_beat。
- **生成**：若 beat_in_wave 在 beat_config 中，则在对应 index 上生成一字：attack_words[i]、counterattack_words[i]、damage_value[i]。
- **进入下一波**：本波最后一个字出现在 beat_in_wave = max(beat_config)。「攻击结束后间隔 interval_time 拍」即中间空拍数为 interval_time，下一波第一个字出现在 beat_in_wave = max(beat_config) + interval_time + 1。当 beat_in_wave == max(beat_config) + interval_time + 1 时设置 wave_start_beat = beat_index、current_wave_index += 1，则下一拍 beat_in_wave = 1，可正常按 beat_config 生成。

### 4.3 FlyingText

- **init_attack(spawn_pos, attack_word, counter_word, damage)**：保存 attack_word、counter_word、damage；显示 attack_word，飞向玩家。
- **deflect()**：切换为 RETURNING，显示 counter_word，飞向敌人。
- **命中敌人**：Enemy 从 FlyingText 取 damage（如 get_damage()），调用 take_damage(damage)。

### 4.4 Enemy

- **受击**：area_entered 时若为 RETURNING 的 FlyingText，则 take_damage(area.get_damage())，并播放 DAMAGE 动画；HP ≤ 0 时播放 DEAD 动画并发出 died。

---

## 五、玩家血条与双方状态动画（新增）

### 5.1 玩家血条

- **玩家自身有血条**：未弹反时被文字「打中」则按该字 damage 扣血；血条 ≤ 0 时死亡（播放 DEAD 后游戏失败）。
- **打中**：文字飞出屏幕未弹反（missed）视为该字攻击到玩家，玩家扣该字对应伤害并播放 DAMAGE 动画。

### 5.2 角色表现：AnimatedSprite2D

- **玩家与敌人均为 AnimatedSprite2D**，五种状态动画：**IDLE**、**DAMAGE**、**HAPPY**、**ATTACK**、**DEAD**。
- **IDLE**：循环播放；**DAMAGE / HAPPY / ATTACK / DEAD**：单次播放。
- **静止时**：双方默认播放 IDLE。

### 5.3 动画触发规则

| 时机 | 玩家 | 敌人 |
|------|------|------|
| 静止 | IDLE（循环） | IDLE（循环） |
| 敌人每吐出一个字 | — | ATTACK（一字一次） |
| 玩家弹反命中一个字 | ATTACK（一次） | — |
| 敌人被回弹文字命中 | — | DAMAGE（一次） |
| 玩家未弹反被文字打中 | DAMAGE（一次） | — |
| 该波**全部**文字被弹回并命中敌人 | HAPPY（一次） | — |
| 该波**全部**文字未弹反、最后一字打到玩家 | — | HAPPY（一次） |
| 死亡 | DEAD（一次） | DEAD（一次） |

### 5.4 波次统计与 HAPPY 判定

- 每个 FlyingText 记录其**所属波次**（spawn_wave_index），用于统计该波内「命中敌人」与「未弹反（miss）」数量。
- **当前波字数** = 该波 `beat_config.size()`。
- 当某波「命中敌人」数 = 当前波字数 → 玩家播放 HAPPY。
- 当某波「miss」数 = 当前波字数 → 敌人播放 HAPPY（在最后一个 miss 时触发）。

---

## 六、资源与配置

| 类型 | 说明 |
|------|------|
| **关卡 JSON** | 如 `res://assets/level_config.json`，含 beat_bpm、waves。 |
| **节拍音效** | `res://assets/music/tap.wav`，每拍播放。 |
| **GameConfig** | 保留：TEXT_SPEED_*、ENEMY_MAX_HP、PLAYER_MAX_HP、MAX_MISS_COUNT、默认 BPM 等；攻击/反击字表改为由关卡 JSON 提供。 |

---

## 七、技术要点小结

1. **时间轴**：全局 beat_index，每拍 tap 音效 + 按 beat_config 生成字。
2. **波次**：wave_start_beat + beat_config + interval_time 决定下一波开始。
3. **FlyingText**：单字/词 + 对应反击字 + 单字伤害，由关卡配置驱动。
4. **兼容**：无关卡或 JSON 异常时，可回退为默认一波或旧逻辑（可选）。
5. **玩家血条**：miss 时按字伤害扣玩家血，HP ≤ 0 播放 DEAD 并失败。
6. **状态动画**：IDLE 循环，ATTACK/DAMAGE/HAPPY/DEAD 单次；按 5.3 表触发；波次统计用于双方 HAPPY。

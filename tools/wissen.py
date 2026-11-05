"""
Wissens-Modell für den E&P Team-Analyzer.
Autor: FGSeRaser – https://github.com/FGSeRaser

Hier steht, was die App über Effekte "weiß":
  EFFEKTE       – alle Effekt-Schlüssel mit deutschem Namen und Gruppe
  TAG_MAP       – HeroPlan-Kategorie (chinesisch) -> eigene Effekt-Schlüssel
  PASSIV_GIBT   – Passiv-ID (Regex) -> Effekte, die der Held dadurch hat
  PASSIV_SCHUTZ – Passiv-ID (Regex) -> Bedrohungen, gegen die er immun ist (Stärke 0..1)
  BEDROHUNGEN   – gegnerische Effekte und womit man sie kontert
  ROLLEN        – Gewichte für spätere Teamvorschläge (Schicht 2)
"""

# --------------------------------------------------------------------------
# Effekt-Schlüssel
# --------------------------------------------------------------------------
# Gruppen: angriff, schaden, schwaechung, kontrolle, mana, heilung, schutz,
#          reinigung, beschwoerung, sonstiges
EFFEKTE = {
    # Angriffsmuster
    "hit_single":      ("Einzelziel-Angriff", "angriff"),
    "hit_aoe":         ("Trifft alle Gegner", "angriff"),
    "hit_three":       ("Trifft 3 Gegner", "angriff"),
    "hit_spread":      ("Streuschaden an Nachbarn", "angriff"),
    "hit_random":      ("Zufällige/variable Ziele", "angriff"),
    "hit_edges":       ("Trifft die Ränder", "angriff"),
    "hit_chain":       ("Kettenangriff", "angriff"),
    "extra_attack":    ("Zusätzlicher Angriff", "angriff"),
    "bypass":          ("Umgeht Verteidigungsboni", "angriff"),
    "unmissable":      ("Verfehlt nie / umgeht Ausweichen", "angriff"),
    "elem_dmg_up":     ("Elementschaden erhöht", "angriff"),
    "atk_up":          ("Angriff erhöht", "angriff"),
    "crit_up":         ("Krit-Chance erhöht", "angriff"),
    "copy_skill":      ("Kopiert/stiehlt Fähigkeiten", "angriff"),

    # Schaden über Zeit
    "dot":             ("Schaden über Zeit", "schaden"),
    "dot_poison":      ("Gift", "schaden"),
    "dot_burn":        ("Brand", "schaden"),
    "dot_bleed":       ("Blutung", "schaden"),
    "dot_frost":       ("Frost", "schaden"),
    "dot_water":       ("Wasser", "schaden"),
    "dot_sand":        ("Sand", "schaden"),
    "dot_curse":       ("Fluch", "schaden"),
    "dot_other":       ("Sonstiger DoT", "schaden"),
    "pain_share":      ("Schmerzempathie", "schaden"),

    # Schwächungen (auf Gegner)
    "def_down":        ("Verteidigung senken", "schwaechung"),
    "elem_def_down":   ("Elementverteidigung senken", "schwaechung"),
    "dmg_taken_up":    ("Erlittenen Schaden erhöhen", "schwaechung"),
    "atk_down":        ("Angriff senken", "schwaechung"),
    "acc_down":        ("Genauigkeit senken (Blind)", "schwaechung"),
    "heal_block":      ("Heilung senken/blockieren", "schwaechung"),
    "maxhp_down":      ("Max. Leben senken", "schwaechung"),
    "revive_block":    ("Wiederbelebung blockieren", "schwaechung"),
    "cleanse_block":   ("Reinigung blockieren", "schwaechung"),
    "buff_block":      ("Boni blockieren (Bonus-Immunität)", "schwaechung"),
    "color_change":    ("Farbe/Position ändern", "schwaechung"),

    # Kontrolle / Mana
    "mana_debuff":     ("Mana-Erzeugung senken/blockieren", "mana"),
    "mana_cut":        ("Mana kürzen", "mana"),
    "mana_steal":      ("Mana stehlen", "mana"),
    "special_block":   ("Spezialfähigkeit blockieren (Stille/Schlaf/Lähmung)", "kontrolle"),
    "insanity":        ("Wahnsinn", "kontrolle"),
    "mana_up":         ("Mana-Erzeugung erhöhen", "mana"),
    "mana_gain":       ("Mana gewinnen", "mana"),

    # Bonus-Manipulation
    "dispel":          ("Boni bannen (Dispel)", "kontrolle"),
    "steal_buff":      ("Boni stehlen", "kontrolle"),
    "buff_turns_down": ("Bonusdauer senken", "kontrolle"),
    "ailment_turns_up":("Leidensdauer verlängern", "kontrolle"),

    # Heilung
    "heal":            ("Sofortheilung", "heilung"),
    "heal_ot":         ("Heilung über Zeit", "heilung"),
    "health_boost":    ("Verstärktes Leben (über Max.)", "heilung"),
    "revive":          ("Wiederbeleben", "heilung"),
    "self_revive":     ("Selbstwiederbelebung", "heilung"),
    "lifesteal":       ("Heilung aus Schaden", "heilung"),
    "heal_up":         ("Heilung erhöhen", "heilung"),

    # Schutz
    "def_up":          ("Verteidigung erhöhen", "schutz"),
    "elem_def_up":     ("Elementverteidigung erhöhen", "schutz"),
    "special_def_up":  ("Schutz gegen Spezialschaden", "schutz"),
    "dmg_reduction":   ("Schadensreduzierung", "schutz"),
    "share_damage":    ("Schadensteilung", "schutz"),
    "dodge":           ("Ausweichen", "schutz"),
    "mimic":           ("Nachahmung (Mimic)", "schutz"),
    "counter":         ("Gegenangriff/Reflektieren", "schutz"),
    "taunt":           ("Spott (Taunt)", "schutz"),
    "stealth":         ("Verstecken/Hinterhalt", "schutz"),
    "ghost":           ("Geisterform", "schutz"),
    "dispel_protect":  ("Schutz vor Bannen", "schutz"),

    # Reinigung / Leiden-Abwehr
    "cleanse":         ("Leiden reinigen (Cleanse)", "reinigung"),
    "ailment_immune":  ("Leiden-Immunität", "reinigung"),
    "ailment_block":   ("Neue Leiden blockieren", "reinigung"),
    "ailment_reflect": ("Leiden reflektieren", "reinigung"),
    "ailment_realloc": ("Leiden umverteilen", "reinigung"),
    "ailment_turns_down": ("Leidensdauer senken", "reinigung"),

    # Beschwörung
    "minions":         ("Lakaien", "beschwoerung"),
    "mega_minions":    ("Mega-Lakaien", "beschwoerung"),
    "minion_destroy":  ("Lakaien zerstören/umgehen", "beschwoerung"),
    "minion_block":    ("Lakaien blockieren", "beschwoerung"),
    "fiend":           ("Feinde (Fiends) setzen", "beschwoerung"),
    "fiend_destroy":   ("Feinde zerstören", "beschwoerung"),
    "fiend_block":     ("Feinde blockieren", "beschwoerung"),

    # Sonstiges
    "self_debuff":     ("Schwächt sich selbst", "sonstiges"),
    "gamble":          ("Glücksspiel/Zufallseffekt", "sonstiges"),
    "field":           ("Feld-Effekt", "sonstiges"),
}

# --------------------------------------------------------------------------
# HeroPlan-Kategorien -> Effekt-Schlüssel
# --------------------------------------------------------------------------
TAG_MAP = {
    "攻击-单体": ["hit_single"], "攻击-全体": ["hit_aoe"], "攻击-范围": ["hit_three"],
    "攻击-邻近轻伤": ["hit_spread"], "攻击-随机": ["hit_random"], "攻击-数量变化": ["hit_random"],
    "攻击-两侧": ["hit_edges"], "攻击-连锁": ["hit_chain"], "攻击-额外攻击": ["extra_attack"],
    "攻击-穿透/绕过": ["bypass"], "攻击-无视闪避": ["unmissable"],
    "攻击-攻击力↑": ["atk_up"], "攻击-递增攻击力↑": ["atk_up"], "攻击-叠加：攻击力↑": ["atk_up"],
    "攻击-成长：攻击力↑": ["atk_up"], "攻击-普通攻击力↑": ["atk_up"], "攻击-技能攻击力↑": ["atk_up"],
    "攻击-递增普通攻击力↑": ["atk_up"], "攻击-面板：攻击力": ["atk_up", "field"],
    "攻击-暴击率↑": ["crit_up"], "攻击-叠加：暴击率↑": ["crit_up"], "攻击-面板：暴击": ["crit_up", "field"],
    "攻击-攻击力↓": ["atk_down"], "攻击-衰退：攻击力↓": ["atk_down"], "攻击-递减攻击力↓": ["atk_down"],
    "攻击-叠加：攻击力↓": ["atk_down"], "攻击-命中率↓": ["acc_down"], "攻击-递减命中率↓": ["acc_down"],
    "攻击-摧毁小兵": ["minion_destroy"], "攻击-穿透小兵": ["minion_destroy"], "攻击-偷取小兵": ["minion_destroy"],
    "攻击-赌博/随机效果": ["gamble"], "攻击-回溯/偷取技能": ["copy_skill"],
    "攻击-抓挠": [], "攻击-利爪": [], "攻击-恼怒": ["insanity"],

    "伤害-持续伤害": ["dot"], "伤害-持续伤害：毒": ["dot", "dot_poison"], "伤害-持续伤害：燃烧": ["dot", "dot_burn"],
    "伤害-持续伤害：流血": ["dot", "dot_bleed"], "伤害-持续伤害：奔涌流血": ["dot", "dot_bleed"],
    "伤害-持续伤害：冰冻": ["dot", "dot_frost"], "伤害-持续伤害：水": ["dot", "dot_water"],
    "伤害-持续伤害：奔涌流水": ["dot", "dot_water"], "伤害-持续伤害：沙": ["dot", "dot_sand"],
    "伤害-持续伤害：诅咒": ["dot", "dot_curse"], "伤害-持续伤害：共振": ["dot", "dot_other"],
    "伤害-持续伤害：风": ["dot", "dot_other"], "伤害-持续伤害：生命偷取": ["dot", "dot_other"],
    "伤害-叠加：持续伤害": ["dot", "dot_other"],
    "伤害-额外伤害": [], "伤害-条件触发": [], "伤害-面板：提高伤害": ["field"],
    "伤害-伤害↑：烈火": ["elem_dmg_up"], "伤害-伤害↑：神圣": ["elem_dmg_up"], "伤害-伤害↑：自然": ["elem_dmg_up"],
    "伤害-伤害↑：冰雪": ["elem_dmg_up"], "伤害-伤害↑：暗黑": ["elem_dmg_up"],
    "伤害-有难同当": ["pain_share"], "伤害-移除小兵造成伤害": [],

    "防御-防御力↓": ["def_down"], "防御-衰退：防御力↓": ["def_down"], "防御-递减防御力↓": ["def_down"],
    "防御-叠加：防御力↓": ["def_down"], "防御-防御↓：特殊技能": ["def_down"],
    "防御-防御↓：自然": ["elem_def_down"], "防御-防御↓：烈火": ["elem_def_down"], "防御-防御↓：冰雪": ["elem_def_down"],
    "防御-防御↓：暗黑": ["elem_def_down"], "防御-防御↓：神圣": ["elem_def_down"],
    "防御-受到伤害↑": ["dmg_taken_up"], "防御-叠加：受到伤害↑": ["dmg_taken_up"],
    "防御-改变颜色/位置": ["color_change"],
    "防御-防御力↑": ["def_up"], "防御-递增防御力↑": ["def_up"], "防御-成长：防御力↑": ["def_up"],
    "防御-叠加：防御力↑": ["def_up"],
    "防御-防御↑：特殊技能": ["special_def_up"],
    "防御-防御↑：自然": ["elem_def_up"], "防御-防御↑：神圣": ["elem_def_up"], "防御-防御↑：暗黑": ["elem_def_up"],
    "防御-防御↑：烈火": ["elem_def_up"], "防御-防御↑：冰雪": ["elem_def_up"],
    "防御-伤害减免": ["dmg_reduction"], "防御-叠加：伤害减免": ["dmg_reduction"],
    "防御-伤害分担": ["share_damage"], "防御-闪避": ["dodge"], "防御-拟态": ["mimic"],
    "防御-反击/反弹": ["counter"], "防御-递增反击": ["counter"], "防御-反击/反弹：烈火": ["counter"],
    "防御-反击/反弹：神圣": ["counter"], "防御-反击/反弹：冰雪": ["counter"], "防御-反击/反弹：自然": ["counter"],
    "防御-反击/反弹：暗黑": ["counter"],
    "防御-嘲讽": ["taunt"], "防御-潜行/伏击": ["stealth"],

    "治疗-即时": ["heal"], "治疗-持续": ["heal_ot"], "治疗-叠加：生命恢复": ["heal_ot"],
    "治疗-提高生命": ["health_boost"], "治疗-自我恢复/提高生命": ["heal"], "治疗-特殊": ["heal"],
    "治疗-复活": ["revive"], "治疗-自我复活": ["self_revive"],
    "治疗-通过伤害治疗": ["lifesteal"], "治疗-伤害量": ["lifesteal"], "治疗-通过小兵治疗": ["heal"],
    "治疗-治疗量↑": ["heal_up"],
    "治疗-最大生命值↓": ["maxhp_down"], "治疗-治疗量↓": ["heal_block"], "治疗-阻止治疗": ["heal_block"],
    "治疗-偷取治疗": ["heal_block"], "治疗-阻止复活": ["revive_block"], "治疗-阻止最大生命值↓": ["ailment_block"],

    "法力-法力生成↓/阻止": ["mana_debuff"], "法力-叠加：法力生成↓": ["mana_debuff"],
    "法力-削减法力": ["mana_cut"], "法力-法力偷取": ["mana_steal"],
    "法力-沉默": ["special_block"], "法力-睡眠": ["special_block"], "法力-麻痹": ["special_block"],
    "法力-莽夫": ["insanity"],
    "法力-法力生成↑": ["mana_up"], "法力-叠加：法力生成↑": ["mana_up"], "法力-面板：法力生成": ["mana_up", "field"],
    "法力-法力恢复": ["mana_gain"], "法力-法力恢复（击杀）": ["mana_gain"], "法力-摧毁小兵获得法力": ["mana_gain"],

    "状态-驱散增益": ["dispel"], "状态-偷取增益": ["steal_buff", "dispel"], "状态-增益无效化": ["buff_block"],
    "状态-减少增益回合": ["buff_turns_down"], "状态-反弹增益": ["dispel"], "状态-替换为负面效果": ["dispel"],
    "状态-净化状态异常": ["cleanse"], "状态-免疫状态异常": ["ailment_immune"], "状态-阻止负面效果": ["ailment_block"],
    "状态-反弹负面效果": ["ailment_reflect"], "状态-负面效果重新分配": ["ailment_realloc"],
    "状态-减少状态异常回合": ["ailment_turns_down"], "状态-替换为增益": ["cleanse"],
    "状态-重置/增加负面效果回合": ["ailment_turns_up"], "状态-重置/增加增益回合": [],
    "状态-增益重新分配": [], "状态-阻止增益驱散": ["dispel_protect"],
    "状态-阻止净化": ["cleanse_block"], "状态-狂乱": ["insanity"], "状态-自我减益": ["self_debuff"],
    "状态-幽灵形态": ["ghost"], "状态-跳舞": [], "状态-阻止小兵": ["minion_block"],
    "状态-阻止恶魔": ["fiend_block"], "状态-小兵腐化": ["minion_destroy"], "状态-根除": ["dispel"],
    "状态-天赋技能无效化": [], "状态-收割": [], "状态-粘糊表面": [], "状态-吞噬粘物": [],

    "召唤-小兵": ["minions"], "召唤-超级小兵": ["mega_minions", "minions"], "召唤-恶魔": ["fiend"],
    "召唤-超级恶魔": ["fiend"], "召唤-摧毁恶魔": ["fiend_destroy"],
}

# --------------------------------------------------------------------------
# Passive: was der Held dadurch zusätzlich KANN (Regex auf Passiv-ID)
# --------------------------------------------------------------------------
PASSIV_GIBT = [
    (r"cleanse", ["cleanse"]),
    (r"dispel_(newest|latest)", ["dispel"]),
    (r"steal_buff", ["steal_buff", "dispel"]),
    (r"never_miss", ["unmissable"]),
    (r"mana_generation_modifier_all_enemies", ["mana_debuff"]),
    (r"reduced_healing_for_all_enemies|prevent_boosted_health", ["heal_block"]),
    (r"reduce_revival_health", ["revive_block"]),
    (r"corrupt_minions|reduce_(big_)?minion_health|bypass_minions|increased_damage_against_minions", ["minion_destroy"]),
    (r"share_received_damage", ["share_damage"]),
    (r"revive_chance|cheat_death", ["self_revive"]),
    (r"special_damage_reduction|dodge_enemy_damage_special", ["special_def_up"]),
    (r"^summon_", ["minions"]),
    (r"mana_regen_debuff", ["mana_debuff"]),
    (r"ransack", ["steal_buff"]),
]

# --------------------------------------------------------------------------
# Passive: wogegen der Held IMMUN ist (Stärke 1.0 = voll, <1 = Chance)
# Schlüssel sind Bedrohungs-Schlüssel (siehe BEDROHUNGEN)
# --------------------------------------------------------------------------
PASSIV_SCHUTZ = [
    (r"^toon_resist", {"ailments": 0.75, "mana_cut": 0.75, "dispel": 0.75}),
    (r"^glass_reflect", {"ailments": 0.6}),
    (r"resist_poison", {"dot_poison": 1}),
    (r"resist_burn", {"dot_burn": 1}),
    (r"resist_bleed", {"dot_bleed": 1}),
    (r"resist_frost", {"dot_frost": 1}),
    (r"resist_water", {"dot_water": 1}),
    (r"resist_sand", {"dot_sand": 1}),
    (r"resist_status_effect_damage", {"dot": 1}),
    (r"resist_insanity", {"insanity": 1}),
    (r"resist_special_blocking", {"special_block": 1}),
    (r"resist_direct_mana_reductions|resist_mana_reductions", {"mana_cut": 1}),
    (r"resist_all_mana_debuffs|resist_mana_debuffs", {"mana_debuff": 1, "mana_steal": 1}),
    (r"resist_mana_generation_modifier|resist_stop_mana_generation", {"mana_debuff": 1}),
    (r"resist_all_defense|resist_defense_modifier|resist_negative_defense", {"def_down": 1}),
    (r"resist_all_attack|resist_attack_modifier|resist_negative_attack", {"atk_down": 1}),
    (r"resist_accuracy", {"acc_down": 1}),
    (r"resist_heal_multiplier", {"heal_block": 1}),
    (r"resist_max_health", {"maxhp_down": 1}),
    (r"resist_all_stealing", {"steal_buff": 1}),
    (r"resist_buff_dispels", {"dispel": 1}),
    (r"resist_buff_immunity", {"buff_block": 1}),
    (r"resist_parasites", {"fiend": 1}),
    (r"resist_negative_minion", {"minions": 1}),
    (r"resist_ailments_(red|blue|green|yellow|purple)", {}),  # farbabhängig, Schicht 2
]

# --------------------------------------------------------------------------
# Bedrohungen: gegnerischer Effekt -> womit kontert man ihn
#   counters = Effekte im EIGENEN Team, die den Effekt wirklich aushebeln
#   weich    = Effekte, die ihn nur abfedern
#   tipp     = kurze Erklärung für die App
# "ailments" ist eine Sammelbedrohung (alle Leiden)
# --------------------------------------------------------------------------
LEIDEN_KONTER = ["cleanse", "ailment_immune", "ailment_block", "ailment_reflect", "ailment_realloc", "ailment_turns_down"]

BEDROHUNGEN = {
    "mana_debuff":  {"label": "Mana-Verlangsamung", "counters": LEIDEN_KONTER, "weich": ["mana_up", "mana_gain"],
                     "tipp": "Reinigen oder Leiden-Immunität, sonst kommen deine Spezialfähigkeiten zu spät."},
    "mana_cut":     {"label": "Mana-Kürzung", "counters": [], "weich": ["mana_gain", "mana_up"],
                     "tipp": "Kann man nicht reinigen – nur Passiv 'Mana-Reduktion widerstehen' oder schnelles Mana hilft."},
    "mana_steal":   {"label": "Mana-Raub", "counters": LEIDEN_KONTER, "weich": ["mana_gain"],
                     "tipp": "Reinigen entfernt den Raub-Effekt."},
    "special_block":{"label": "Stille/Schlaf/Lähmung", "counters": LEIDEN_KONTER, "weich": [],
                     "tipp": "Ohne Reinigung kann der Held seine Spezialfähigkeit nicht nutzen."},
    "insanity":     {"label": "Wahnsinn", "counters": LEIDEN_KONTER, "weich": [],
                     "tipp": "Wahnsinnige Helden greifen zufällig auch Verbündete an."},
    "dot":          {"label": "Schaden über Zeit", "counters": LEIDEN_KONTER, "weich": ["heal", "heal_ot", "health_boost"],
                     "tipp": "Reinigen – oder mit Heilung gegenhalten."},
    "def_down":     {"label": "Verteidigung gesenkt", "counters": LEIDEN_KONTER, "weich": ["def_up", "dmg_reduction"],
                     "tipp": "Gegner machen dann deutlich mehr Schaden – reinigen oder Verteidigung hochziehen."},
    "elem_def_down":{"label": "Elementverteidigung gesenkt", "counters": LEIDEN_KONTER, "weich": ["elem_def_up", "def_up"],
                     "tipp": "Trifft meist eine Farbe besonders hart."},
    "dmg_taken_up": {"label": "Erlittener Schaden erhöht", "counters": LEIDEN_KONTER, "weich": ["dmg_reduction"],
                     "tipp": "Wirkt wie Verteidigung runter."},
    "atk_down":     {"label": "Angriff gesenkt", "counters": LEIDEN_KONTER, "weich": ["atk_up"],
                     "tipp": "Deine Angreifer machen weniger Schaden."},
    "acc_down":     {"label": "Blind (Genauigkeit runter)", "counters": LEIDEN_KONTER + ["unmissable"], "weich": [],
                     "tipp": "Angriffe verfehlen – reinigen oder Helden mit 'verfehlt nie' nutzen."},
    "heal_block":   {"label": "Heilung blockiert/gesenkt", "counters": LEIDEN_KONTER, "weich": ["health_boost", "lifesteal"],
                     "tipp": "Erst reinigen, dann heilen."},
    "maxhp_down":   {"label": "Max. Leben gesenkt", "counters": LEIDEN_KONTER, "weich": [],
                     "tipp": "Senkt dauerhaft, wie viel du heilen kannst."},
    "revive_block": {"label": "Wiederbelebung blockiert", "counters": [], "weich": [],
                     "tipp": "Nur wichtig, wenn dein Team auf Wiederbelebung baut."},
    "cleanse_block":{"label": "Reinigung blockiert", "counters": ["ailment_immune", "ailment_block", "ailment_reflect"], "weich": [],
                     "tipp": "Hier helfen nur Immunität oder Leiden blockieren – Reinigen geht nicht."},
    "buff_block":   {"label": "Boni blockiert", "counters": LEIDEN_KONTER, "weich": [],
                     "tipp": "Deine Boni greifen nicht, bis du reinigst."},
    "dispel":       {"label": "Boni werden gebannt", "counters": ["dispel_protect"], "weich": [],
                     "tipp": "Boni lieber erst nach dem Bannen des Gegners setzen oder Bann-Schutz nutzen."},
    "steal_buff":   {"label": "Boni werden gestohlen", "counters": ["dispel_protect"], "weich": [],
                     "tipp": "Gestohlene Boni stärken den Gegner – vorsichtig mit starken Boni."},
    "taunt":        {"label": "Spott (Taunt)", "counters": ["dispel", "steal_buff"], "weich": ["hit_aoe", "bypass"],
                     "tipp": "Bannen, sonst geht aller Einzelschaden auf den Tank."},
    "counter":      {"label": "Gegenangriff/Reflektieren", "counters": ["dispel", "steal_buff", "bypass"], "weich": [],
                     "tipp": "Erst bannen oder umgehen, sonst schadest du dir selbst."},
    "def_up":       {"label": "Gegner mit Verteidigung hoch", "counters": ["dispel", "steal_buff", "bypass"], "weich": ["def_down"],
                     "tipp": "Bannen oder umgehen."},
    "dmg_reduction":{"label": "Gegner mit Schadensreduzierung", "counters": ["dispel", "steal_buff", "bypass"], "weich": [],
                     "tipp": "Bannen oder umgehen."},
    "dodge":        {"label": "Ausweichen", "counters": ["dispel", "steal_buff", "unmissable"], "weich": ["bypass"],
                     "tipp": "Helden mit 'verfehlt nie' oder Bannen."},
    "mimic":        {"label": "Nachahmung (Mimic)", "counters": ["dispel", "steal_buff"], "weich": ["bypass"],
                     "tipp": "Mimic kopiert deine Spezialfähigkeit – erst bannen."},
    "minions":      {"label": "Lakaien", "counters": ["minion_destroy", "minion_block"], "weich": ["hit_aoe"],
                     "tipp": "Lakaien fangen Schaden ab – zerstören, umgehen oder mit Flächenschaden abräumen."},
    "fiend":        {"label": "Feinde (Fiends)", "counters": ["fiend_destroy", "fiend_block"], "weich": [],
                     "tipp": "Feinde entziehen Leben/Mana – zerstören oder blockieren."},
    "revive":       {"label": "Gegner beleben wieder", "counters": ["revive_block"], "weich": [],
                     "tipp": "Wiederbelebung blockieren oder Ziele schnell nacheinander töten."},
    "heal":         {"label": "Gegner heilen stark", "counters": ["heal_block"], "weich": ["maxhp_down", "dispel"],
                     "tipp": "Heilung blockieren, sonst zieht sich der Kampf."},
    "self_revive":  {"label": "Gegner beleben sich selbst", "counters": ["revive_block"], "weich": [],
                     "tipp": "Wiederbelebung blockieren."},
    "ghost":        {"label": "Geisterform", "counters": [], "weich": ["hit_aoe", "dispel"],
                     "tipp": "Ziele in Geisterform sind schwer zu treffen."},
    "stealth":      {"label": "Verstecken", "counters": [], "weich": ["hit_aoe", "hit_random"],
                     "tipp": "Flächenschaden trifft auch versteckte Helden."},
    "ailments":     {"label": "Leiden allgemein", "counters": LEIDEN_KONTER, "weich": [],
                     "tipp": "Sammelbegriff für alle negativen Statusänderungen."},
}

# Spezielle DoT-Bedrohungen erben vom allgemeinen DoT
for _k in ["dot_poison", "dot_burn", "dot_bleed", "dot_frost", "dot_water", "dot_sand", "dot_curse"]:
    BEDROHUNGEN[_k] = {"label": EFFEKTE[_k][0], "counters": BEDROHUNGEN["dot"]["counters"],
                       "weich": BEDROHUNGEN["dot"]["weich"], "tipp": BEDROHUNGEN["dot"]["tipp"]}

# Diese Bedrohungen zählen als "Leiden" – eine Leiden-Immunität (ailments) schützt davor
LEIDEN_BEDROHUNGEN = ["mana_debuff", "mana_steal", "special_block", "insanity", "dot", "dot_poison", "dot_burn",
                      "dot_bleed", "dot_frost", "dot_water", "dot_sand", "dot_curse", "def_down", "elem_def_down",
                      "dmg_taken_up", "atk_down", "acc_down", "heal_block", "maxhp_down", "buff_block"]

# --------------------------------------------------------------------------
# Rollen-Gewichte (Grundlage für Schicht 2: Teamvorschläge)
# --------------------------------------------------------------------------
ROLLEN = {
    "tank": {"label": "Tank (Verteidigung Mitte)",
             "effekte": {"taunt": 3, "def_up": 2, "counter": 2, "dmg_reduction": 2, "share_damage": 1,
                         "mimic": 2, "dodge": 1, "heal": 1, "self_revive": 1, "special_def_up": 1},
             "werte": {"health": 0.5, "defense": 0.4, "attack": 0.1}},
    "flanke": {"label": "Flanke (Verteidigung außen)",
               "effekte": {"hit_aoe": 2, "dot": 1, "mana_debuff": 2, "dispel": 2, "def_down": 1,
                           "mana_cut": 2, "special_block": 2, "insanity": 1},
               "werte": {"attack": 0.5, "health": 0.3, "defense": 0.2}},
    "angreifer": {"label": "Angreifer (Schaden)",
                  "effekte": {"hit_aoe": 2, "hit_three": 1, "atk_up": 2, "def_down": 2, "elem_def_down": 2,
                              "bypass": 2, "dmg_taken_up": 2, "extra_attack": 1, "crit_up": 1},
                  "werte": {"attack": 0.7, "health": 0.2, "defense": 0.1}},
    "heiler": {"label": "Heiler/Support",
               "effekte": {"heal": 2, "heal_ot": 2, "cleanse": 3, "revive": 2, "health_boost": 2,
                           "ailment_immune": 2, "ailment_block": 2},
               "werte": {"health": 0.4, "defense": 0.3, "attack": 0.3}},
    "konter": {"label": "Bannen & Kontrolle",
               "effekte": {"dispel": 3, "steal_buff": 2, "mana_debuff": 2, "special_block": 2,
                           "mana_cut": 2, "buff_block": 1, "cleanse_block": 1},
               "werte": {"attack": 0.4, "health": 0.3, "defense": 0.3}},
}


# ==========================================================================
# Englische Texte (für die Sprachumschaltung)
# ==========================================================================
EFFEKTE_EN = {
    "hit_single": "Single-target attack", "hit_aoe": "Hits all enemies", "hit_three": "Hits 3 enemies",
    "hit_spread": "Spread damage to neighbours", "hit_random": "Random/variable targets", "hit_edges": "Hits the edges",
    "hit_chain": "Chain attack", "extra_attack": "Extra attack", "bypass": "Bypasses defensive buffs",
    "unmissable": "Never misses / ignores dodge", "elem_dmg_up": "Elemental damage up", "atk_up": "Attack up",
    "crit_up": "Crit chance up", "copy_skill": "Copies/steals skills",
    "dot": "Damage over time", "dot_poison": "Poison", "dot_burn": "Burn", "dot_bleed": "Bleed",
    "dot_frost": "Frost", "dot_water": "Water", "dot_sand": "Sand", "dot_curse": "Curse", "dot_other": "Other DoT",
    "pain_share": "Pain empathy",
    "def_down": "Defense down", "elem_def_down": "Elemental defense down", "dmg_taken_up": "Damage received up",
    "atk_down": "Attack down", "acc_down": "Accuracy down (blind)", "heal_block": "Healing down/blocked",
    "maxhp_down": "Max health down", "revive_block": "Blocks revive", "cleanse_block": "Blocks cleanse",
    "buff_block": "Blocks buffs (buff immunity)", "color_change": "Changes color/position",
    "mana_debuff": "Mana generation down/blocked", "mana_cut": "Mana reduction", "mana_steal": "Mana steal",
    "special_block": "Blocks special (silence/sleep/paralysis)", "insanity": "Insanity",
    "mana_up": "Mana generation up", "mana_gain": "Mana gain",
    "dispel": "Dispel buffs", "steal_buff": "Steal buffs", "buff_turns_down": "Shorten buffs",
    "ailment_turns_up": "Extend ailments",
    "heal": "Instant heal", "heal_ot": "Heal over time", "health_boost": "Boosted health (over max)",
    "revive": "Revive", "self_revive": "Self revive", "lifesteal": "Heal from damage", "heal_up": "Healing up",
    "def_up": "Defense up", "elem_def_up": "Elemental defense up", "special_def_up": "Special damage protection",
    "dmg_reduction": "Damage reduction", "share_damage": "Damage sharing", "dodge": "Dodge", "mimic": "Mimic",
    "counter": "Counterattack/reflect", "taunt": "Taunt", "stealth": "Stealth/ambush", "ghost": "Ghost form",
    "dispel_protect": "Dispel protection",
    "cleanse": "Cleanse ailments", "ailment_immune": "Ailment immunity", "ailment_block": "Block new ailments",
    "ailment_reflect": "Reflect ailments", "ailment_realloc": "Reallocate ailments",
    "ailment_turns_down": "Shorten ailments",
    "minions": "Minions", "mega_minions": "Mega minions", "minion_destroy": "Destroy/bypass minions",
    "minion_block": "Block minions", "fiend": "Fiends", "fiend_destroy": "Destroy fiends", "fiend_block": "Block fiends",
    "self_debuff": "Self debuff", "gamble": "Gamble/random effect", "field": "Field effect",
}

BEDROHUNGEN_EN = {
    "mana_debuff": ("Mana slow", "Cleanse or ailment immunity, otherwise your specials come too late."),
    "mana_cut": ("Mana reduction", "Can't be cleansed – only the passive 'Resist mana reduction' or fast mana helps."),
    "mana_steal": ("Mana steal", "Cleansing removes the steal effect."),
    "special_block": ("Silence/sleep/paralysis", "Without cleanse the hero can't use the special skill."),
    "insanity": ("Insanity", "Insane heroes randomly hit allies too."),
    "dot": ("Damage over time", "Cleanse – or out-heal it."),
    "def_down": ("Defense lowered", "Enemies deal much more damage – cleanse or raise defense."),
    "elem_def_down": ("Elemental defense lowered", "Usually hits one color especially hard."),
    "dmg_taken_up": ("Damage received up", "Works like defense down."),
    "atk_down": ("Attack lowered", "Your attackers deal less damage."),
    "acc_down": ("Blind (accuracy down)", "Attacks miss – cleanse or use heroes that never miss."),
    "heal_block": ("Healing blocked/lowered", "Cleanse first, then heal."),
    "maxhp_down": ("Max health lowered", "Permanently lowers how much you can heal."),
    "revive_block": ("Revive blocked", "Only matters if your team relies on revives."),
    "cleanse_block": ("Cleanse blocked", "Only immunity or ailment blocking helps – cleansing won't work."),
    "buff_block": ("Buffs blocked", "Your buffs don't apply until you cleanse."),
    "dispel": ("Buffs get dispelled", "Buff after the enemy dispel, or use dispel protection."),
    "steal_buff": ("Buffs get stolen", "Stolen buffs empower the enemy – careful with strong buffs."),
    "taunt": ("Taunt", "Dispel it, otherwise all single-target damage goes to the tank."),
    "counter": ("Counterattack/reflect", "Dispel or bypass first, otherwise you hurt yourself."),
    "def_up": ("Enemy defense up", "Dispel or bypass."),
    "dmg_reduction": ("Enemy damage reduction", "Dispel or bypass."),
    "dodge": ("Dodge", "Use heroes that never miss, or dispel."),
    "mimic": ("Mimic", "Mimic copies your special – dispel first."),
    "minions": ("Minions", "Minions soak damage – destroy, bypass or clear them with AoE."),
    "fiend": ("Fiends", "Fiends drain health/mana – destroy or block them."),
    "revive": ("Enemies revive", "Block revives or kill targets in quick succession."),
    "heal": ("Enemies heal a lot", "Block healing, otherwise the fight drags on."),
    "self_revive": ("Enemies revive themselves", "Block revives."),
    "ghost": ("Ghost form", "Targets in ghost form are hard to hit."),
    "stealth": ("Stealth", "AoE also hits hidden heroes."),
    "ailments": ("Ailments in general", "Collective term for all negative status effects."),
}
for _k in ["dot_poison", "dot_burn", "dot_bleed", "dot_frost", "dot_water", "dot_sand", "dot_curse"]:
    BEDROHUNGEN_EN[_k] = (EFFEKTE_EN[_k], BEDROHUNGEN_EN["dot"][1])

ROLLEN_EN = {"tank": "Tank (defense center)", "flanke": "Flank (defense outside)", "angreifer": "Attacker (damage)",
             "heiler": "Healer/support", "konter": "Dispel & control"}


# ==========================================================================
# Truppen
# ==========================================================================
# Klassen-Schlüssel wie im Spiel (characters.json classType, kleingeschrieben)
KLASSEN = ["wizard", "ranger", "paladin", "druid", "barbarian", "monk", "sorcerer", "rogue", "fighter", "cleric"]

# Passive der legendären Truppen: Schlüssel -> (deutsch, englisch, passende Rollen)
TRUPPEN_PASSIVE = {
    "crit":          ("Krit-Chance erhöht", "Critical chance up", ["angreifer"]),
    "atk_add":       ("Zusätzlicher Angriff", "Attack addition", ["angreifer", "flanke"]),
    "atk_red":       ("Senkt Angriff des Gegners", "Attack reduction", ["tank", "konter"]),
    "def_add":       ("Zusätzliche Verteidigung", "Defense addition", ["tank"]),
    "def_red":       ("Senkt Verteidigung des Gegners", "Defense reduction", ["angreifer"]),
    "ailment_dmg":   ("Weniger Schaden durch Leiden", "Debuff damage reduction", ["tank", "heiler"]),
    "resist":        ("Leiden widerstehen", "Resist debuffs", ["tank", "heiler", "flanke"]),
    "special_dmg":   ("Mehr Spezialschaden", "Increase special damage", ["angreifer", "flanke"]),
    "special_def":   ("Weniger Spezialschaden erhalten", "Special damage reduction", ["tank"]),
    "heal_extra":    ("Extra-Heilung beim Heilen", "Extra heal on heal", ["heiler"]),
}

# Legendäre Truppen (gibt es in allen 5 Farben): Name, Hauptklasse, Nebenklasse, Passiv
TRUPPEN_LEGENDAER = [
    ("Arcane Hunter", "ranger", "sorcerer", "crit"),
    ("Battle Master Assassin", "rogue", "fighter", "atk_add"),
    ("Devoted Knight", "paladin", "cleric", "ailment_dmg"),
    ("Divine Cleric", "cleric", "paladin", "resist"),
    ("Eldest Wizard", "wizard", "ranger", "special_dmg"),
    ("Elite Knight", "paladin", "rogue", "def_add"),
    ("Enchanted Ent", "druid", "barbarian", "ailment_dmg"),
    ("Enlightened Tree Spirit", "druid", "wizard", "def_add"),
    ("Eternal Hunter", "ranger", "wizard", "atk_red"),
    ("Furious Monk", "monk", "barbarian", "heal_extra"),
    ("Hunter Mage", "sorcerer", "ranger", "def_red"),
    ("Majestic Minotaur", "barbarian", "druid", "atk_add"),
    ("Mighty Monk", "monk", "sorcerer", "resist"),
    ("Royal Sorcerer", "sorcerer", "monk", "special_def"),
    ("Serene Brute", "barbarian", "monk", "special_dmg"),
    ("Shaman Wizard", "wizard", "druid", "special_def"),
    ("Swashbuckler Fighter", "fighter", "rogue", "atk_red"),
    ("Unseen Assassin", "rogue", "paladin", "crit"),
    ("Unstoppable Fighter", "fighter", "cleric", "def_red"),
    ("Unwavering Cleric", "cleric", "fighter", "heal_extra"),
]

# Epische Truppentypen (je Farbe eine) – Mana-Stufen laut Spielguides
TRUPPEN_EPISCH = [
    {"id": "mana", "de": "Mana-Truppe", "en": "Mana troop", "sterne": 4,
     "mana": [[1, 5], [5, 7], [11, 9], [17, 11], [23, 13], [29, 15]],
     "text_de": "Schnellere Spezialfähigkeit (bis +15 % Mana). Standard für Angriff, Raids und Krieg.",
     "text_en": "Faster special (up to +15% mana). Standard for attack, raids and war.",
     "modi": ["angriff", "krieg"]},
    {"id": "krit", "de": "Krit-Truppe", "en": "Crit troop", "sterne": 4,
     "krit": [[1, 5], [3, 6], [7, 7], [10, 8], [14, 9], [18, 10], [21, 11], [25, 12], [30, 13]],
     "text_de": "Mehr Verteidigung und bis 13 % kritische Treffer (doppelter Steinschaden). Für Verteidigung und Titanen.",
     "text_en": "More defense and up to 13% critical hits (double tile damage). For defense and titans.",
     "modi": ["verteidigung", "titan"]},
    {"id": "magie", "de": "Magie-Truppe (Turm der Magie)", "en": "Magic troop (Tower of Magic)", "sterne": 4,
     "mana": [[1, 5], [5, 8], [11, 11], [17, 14], [23, 17], [29, 20]],
     "namen": {"blau": "Veteran Wizard", "gruen": "Ancient Wizard", "rot": "Merciless Wizards",
               "gelb": "Divine Wizards", "lila": "Wayward Wizards"},
     "text_de": "Stärkste Mana-Truppe (bis +20 %). Ideal für langsame und mittlere Helden.",
     "text_en": "Strongest mana troop (up to +20%). Ideal for slow and average heroes.",
     "modi": ["angriff", "krieg"]},
    {"id": "styx", "de": "Styx-Truppe (Zyklop)", "en": "Styx troop (Cyclops)", "sterne": 4,
     "mana": [[1, 5], [5, 8], [12, 11], [16, 14], [23, 17], [27, 20]],
     "namen": {"blau": "Conjurer Cyclopes", "gruen": "Menacing Cyclopes", "rot": "Ferocious Cyclopes",
               "gelb": "Fierce Cyclopes", "lila": "Savage Cyclopes"},
     "text_de": "Bis +20 % Mana und Chance, Verteidigungsboni zu umgehen. Sehr stark im Angriff.",
     "text_en": "Up to +20% mana plus a chance to bypass defensive buffs. Very strong on offense.",
     "modi": ["angriff", "krieg"]},
    {"id": "ninja", "de": "Ninja-Truppe", "en": "Ninja troop", "sterne": 4,
     "umgehen": [[1, 5], [5, 7], [11, 9], [17, 11], [23, 13], [29, 15]],
     "namen": {"blau": "Wakizashi Ninja", "gruen": "Kusarigama Ninjas", "rot": "Sai Ninjas",
               "gelb": "Nunchaku Ninjas", "lila": "Bo Ninjas"},
     "text_de": "Höchster Angriff, bis 15 % Chance pro Stein, Verteidigungsboni zu umgehen. Kein Mana-Bonus.",
     "text_en": "Highest attack, up to 15% chance per tile to bypass defensive buffs. No mana bonus.",
     "modi": ["angriff", "titan"]},
]

# Mana-Schwellen: Tempo -> [(nötiger Mana-Bonus in %, Steine)]
MANA_SCHWELLEN = {
    # nur Werte, die in den Guides belegt sind (inkl. aller Mana-Quellen: Truppe, Kostüm +5 %, Embleme +2/4 %)
    "fast": [[0, 8], [15, 7]],
    "average": [[0, 10], [13, 9]],
    "slow": [[0, 12], [11, 11]],
    "very_slow": [[0, 14], [7, 13]],
}

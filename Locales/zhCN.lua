-- 简体中文翻译 — 每一条请逐条审核
-- 术语参考（国服官方译名）：
--   Hand of Gul'dan      → 古尔丹之手
--   Dominion of Argus    → 阿古斯的统御
--   Summon Demonic Tyrant→ 召唤恶魔暴君
--   Demonology           → 恶魔学识
DAT.RegisterLocale("zhCN", {

    -- Pages / tree
    ["Main"]             = "主要",
    ["Fonts"]            = "字体",
    ["Border"]           = "边框",
    ["Colors"]           = "颜色",
    ["Glow"]             = "光效",
    ["Announcement"]     = "播报",

    -- Anchors
    ["Center"] = "居中",
    ["Top"]    = "顶部",
    ["Bottom"] = "底部",
    ["Left"]   = "左侧",
    ["Right"]  = "右侧",

    -- Visibility modes
    ["Always"]             = "始终显示",
    ["In Combat Only"]     = "仅战斗中",
    ["Out of Combat Only"] = "仅非战斗中",
    ["Never"]              = "从不显示",

    -- Outline options
    ["Outline"]                = "描边",
    ["Thick Outline"]          = "粗描边",
    ["Monochrome"]             = "单色",
    ["Outline + Monochrome"]   = "描边 + 单色",
    ["Thick + Monochrome"]     = "粗描边 + 单色",
    ["None"]                   = "无",

    -- Glow types
    -- ["Proc Glow"]     = "触发光效",
    -- ["Pixel Glow"]    = "像素光效",
    -- ["Autocast Glow"] = "自动施法光效",
    -- ["Button Glow"]   = "按钮光效",

    -- Main page
    ["UI"]                      = "界面",
    ["UI Scale"]                = "界面缩放",
    ["Language"]                = "语言",
    ["Requires /reload after change."] = "修改后需要 /reload 生效。",
    ["Language change requires reloading the UI. Reload now?"] = "切换语言需要重载界面。现在重载？",
    -- ["Reload"] = "重载",
    -- ["Later"]  = "稍后",
    ["Auto (Client)"]           = "自动（跟随客户端）",
    ["Icon"]                    = "图标",
    ["Icon Size"]               = "图标大小",
    ["Icon Zoom"]               = "图标缩放",
    ["Icon Brightness (%)"]     = "图标亮度 (%)",
    ["Icon Alpha (%)"]          = "图标透明度 (%)",
    ["Position"]                = "位置",
    ["Position X"]              = "横坐标 X",
    ["Position Y"]              = "纵坐标 Y",
    ["Lock Position"]           = "锁定位置",
    ["Display"]                 = "显示",
    ["Show Tracker"]            = "显示图标",
    ["Hide When No Buff"]       = "无Buff时隐藏",
    ["Hide Delay (sec)"]        = "隐藏延迟（秒）",
    ["Count Reset Delay (sec)"] = "计数重置延迟（秒）",

    -- Fonts page
    ["Font"]              = "字体",
    ["Shadow"]            = "阴影",
    ["Shadow X Offset"]   = "阴影 X 偏移",
    ["Shadow Y Offset"]   = "阴影 Y 偏移",
    ["Shadow Color"]      = "阴影颜色",
    ["Count Text"]        = "古手计数",
    ["Font Size"]         = "字号",
    ["Anchor"]            = "锚点",
    ["Offset X"]          = "X 偏移",
    ["Offset Y"]          = "Y 偏移",
    ["Demon Count Text"]  = "恶魔计数",
    ["Timer Text"]        = "计时",
    ["Show \"s\" Suffix"] = "显示“s”后缀",

    -- Border page
    ["Border Style"]       = "边框样式",
    ["Border Size (px)"]   = "边框大小（px）",
    ["Border Offset (px)"] = "边框偏移（px）",
    ["Border Colors"]      = "边框颜色",
    ["Active Border"]      = "激活时边框",
    ["Inactive Border"]    = "未激活边框",

    -- Colors page
    ["Count Colors"]              = "计数颜色",
    ["Active Count"]              = "激活时计数",
    ["Inactive Count"]            = "未激活计数",
    ["Demon Count Colors"]        = "恶魔计数颜色",
    ["Active Demon Count"]        = "激活时恶魔计数",
    ["Inactive Demon Count"]      = "未激活恶魔计数",
    ["Timer Colors"]              = "计时颜色",
    ["Timer"]                     = "计时",
    ["Enable Timer Warning Color"] = "启用计时警告颜色",
    ["Change the timer text color when time is running low."] = "剩余时间较少时改变计时文本颜色。",
    ["Warn When <= (sec)"]        = "剩余时间 ≤（秒）",
    ["Timer Warning"]             = "计时警告颜色",

    -- Glow page
    ["Enable Glow"]        = "启用光效",
    ["Glow Type"]          = "光效类型",
    ["Glow Color"]         = "光效颜色",
    ["Pixel Glow Options"] = "Pixel Glow选项",
    ["Lines"]              = "线条数",
    ["Frequency"]          = "频率",
    ["Length (0=auto)"]    = "长度（0=自动）",
    ["Thickness"]          = "粗细",
    ["X Offset"]           = "X 偏移",
    ["Y Offset"]           = "Y 偏移",

    -- Announce page
    ["Start"]    = "开始",
    ["End"]      = "结束",
    ["HoG Count"] = "古手次数",
    ["Demons"]   = "恶魔数量",
    ["Dominion"] = "阿古斯",
    -- AND / OR 保留英文原文
    ["System"]   = "系统",
    ["Party"]    = "小队",
    ["Say"]      = "说",
    ["Yell"]     = "喊",
    -- ["If"]       = "如果",
    ["Enabled"]  = "启用",
    ["Delete"]   = "删除",
    ["+ Add Condition"]    = "添加条件",
    ["+ Add Announcement"] = "添加播报",
    ["Message"]            = "消息",
    ["Tags:\n- |cffffd700{count:hog}|r: Hand of Gul'dan casts\n- |cffffd700{count:demon}|r: Demons summoned"]
        = "标签：\n- |cffffd700{count:hog}|r：古尔丹之手施放次数\n- |cffffd700{count:demon}|r：召唤出的恶魔数量",
    ["|cffaaaaaaNote: Say and Yell only work inside instances.|r"]
        = "|cffaaaaaa注意：说和喊仅在副本内生效。|r",
    ["|cff888888No rules configured. Click '+ Add Announcement' above.|r"]
        = "|cff888888尚未配置规则。点击上方“+ 添加播报”。|r",

    -- Default announce rule messages (used when DB is first initialized)
    ["Dominion of Argus active!"] = "阿古斯的统御已激活！",
    ["Dominion ended — HoG: {count:hog}  Demons: {count:demon}"]
        = "阿古斯的统御结束 — 古尔丹之手：{count:hog}  恶魔：{count:demon}",

    -- Runtime / chat
    ["|cff9482c9[DoA Tracker]|r AceGUI-3.0 is not available."]
        = "|cff9482c9[DoA Tracker]|r AceGUI-3.0 不可用。",
    ["loaded. Type"]         = "已加载。输入",
    ["to open settings."]    = "打开设置。",
})

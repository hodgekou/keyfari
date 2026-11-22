// SPDX-License-Identifier: GPL-3.0-only

import Foundation

/// The interface language chosen in the settings.
public enum AppLanguage: String, Codable, Sendable, CaseIterable {
    /// Follow the language order of the system.
    case system
    case english
    case chinese
    case japanese

    /// The language to show, given the user's system language preferences
    /// (`Locale.preferredLanguages`, most preferred first).
    public func resolved(preferredLanguages: [String]) -> Language {
        switch self {
        case .english: return .english
        case .chinese: return .chinese
        case .japanese: return .japanese
        case .system:
            for identifier in preferredLanguages {
                let code = identifier.lowercased()
                if code.hasPrefix("zh") { return .chinese }
                if code.hasPrefix("ja") { return .japanese }
                if code.hasPrefix("en") { return .english }
            }
            return .english
        }
    }
}

/// A language the interface is translated into.
public enum Language: String, Sendable, CaseIterable {
    case english
    case chinese
    case japanese

    /// The language's own name for itself.
    public var nativeName: String {
        switch self {
        case .english: "English"
        case .chinese: "中文"
        case .japanese: "日本語"
        }
    }
}

/// Looks up interface text. The English text is the key, so a missing entry falls back to English.
public enum Localizer {
    public static func text(_ english: String, in language: Language) -> String {
        guard language != .english, let entry = table[english] else { return english }
        return language == .chinese ? entry.chinese : entry.japanese
    }

    /// Translates a format string and fills in its arguments.
    public static func text(_ english: String, in language: Language, _ arguments: [any CVarArg]) -> String {
        String(format: text(english, in: language), arguments: arguments)
    }

    struct Entry {
        let chinese: String
        let japanese: String
    }

    static let table: [String: Entry] = [
        // Panes
        "General": Entry(chinese: "通用", japanese: "一般"),
        "Hints": Entry(chinese: "标签", japanese: "ヒント"),
        "Scrolling": Entry(chinese: "滚动", japanese: "スクロール"),
        "AI Detection": Entry(chinese: "AI 识别", japanese: "AI 検出"),
        "Stats": Entry(chinese: "统计", japanese: "統計"),
        "Desktops": Entry(chinese: "桌面", japanese: "デスクトップ"),
        "Desktops and Mission Control": Entry(chinese: "桌面切换与调度中心", japanese: "デスクトップと Mission Control"),
        "Shortcuts, startup, permissions and ignored apps": Entry(
            chinese: "快捷键、启动、权限与忽略的应用", japanese: "ショートカット、起動、権限、除外するアプリ"),
        "How labels look and behave": Entry(chinese: "标签的外观与行为", japanese: "ラベルの外観と動作"),
        "Speed and direction": Entry(chinese: "速度与方向", japanese: "速度と方向"),
        "Activity counts that stay on this Mac": Entry(chinese: "仅保存在本机的使用统计", japanese: "この Mac にのみ保存される使用統計"),
        "Find text that apps do not expose": Entry(chinese: "找出应用没有暴露的文字", japanese: "アプリが公開していないテキストを見つける"),
        "Keyboard navigation": Entry(chinese: "键盘导航", japanese: "キーボード操作"),
        "Keyfari Settings": Entry(chinese: "Keyfari 设置", japanese: "Keyfari 設定"),

        // General
        "Shortcuts": Entry(chinese: "快捷键", japanese: "ショートカット"),
        "Show hints": Entry(chinese: "显示标签", japanese: "ヒントを表示"),
        "Label everything clickable": Entry(chinese: "给所有可点击的元素打标签", japanese: "クリックできる要素すべてにラベルを付ける"),
        "Search": Entry(chinese: "搜索", japanese: "検索"),
        "Find an element by its text": Entry(chinese: "按文字查找元素", japanese: "テキストで要素を探す"),
        "Scroll mode": Entry(chinese: "滚动模式", japanese: "スクロールモード"),
        "Scroll with H J K L": Entry(chinese: "用 H J K L 滚动", japanese: "H J K L でスクロール"),
        "Repeat last click": Entry(chinese: "重复上一次点击", japanese: "直前のクリックを繰り返す"),
        "Click the element you clicked last once more": Entry(chinese: "再点一次上次点过的那个元素", japanese: "最後にクリックした要素をもう一度クリック"),
        "There is no click to repeat yet.": Entry(chinese: "还没有可以重复的点击。", japanese: "繰り返すクリックがまだありません。"),
        "The element you clicked last is not on screen.": Entry(chinese: "上次点击的元素不在屏幕上。", japanese: "最後にクリックした要素は画面上にありません。"),
        "Two modes share a shortcut, so the defaults are in use.": Entry(
            chinese: "有两个模式使用了相同的快捷键,已改用默认设置。", japanese: "2 つのモードが同じショートカットを使っているため、デフォルトを使用しています。"),
        "Press a shortcut…": Entry(chinese: "请按下快捷键…", japanese: "ショートカットを押してください…"),
        "Click, then press the new shortcut. Esc cancels.": Entry(chinese: "点击后按下新的快捷键,按 Esc 取消。", japanese: "クリックしてから新しいショートカットを押します。Esc でキャンセル。"),
        "Startup": Entry(chinese: "启动", japanese: "起動"),
        "Launch at login": Entry(chinese: "登录时启动", japanese: "ログイン時に起動"),
        "Start Keyfari when you log in": Entry(chinese: "登录系统时自动启动 Keyfari", japanese: "ログイン時に Keyfari を自動的に起動する"),
        "Updates": Entry(chinese: "更新", japanese: "アップデート"),
        "Check for updates": Entry(chinese: "检查更新", japanese: "アップデートを確認"),
        "Once a day, looks for a newer version. Nothing about you or this Mac is sent": Entry(
            chinese: "每天检查一次是否有新版本,不发送任何关于你或这台 Mac 的信息", japanese: "1 日 1 回、新しいバージョンを確認します。あなたやこの Mac に関する情報は送信しません"),
        "Version %@": Entry(chinese: "版本 %@", japanese: "バージョン %@"),
        "Check Now": Entry(chinese: "立即检查", japanese: "今すぐ確認"),
        "Check for Updates…": Entry(chinese: "检查更新…", japanese: "アップデートを確認…"),
        "Show menu bar icon": Entry(chinese: "显示菜单栏图标", japanese: "メニューバーにアイコンを表示"),
        "When hidden, open Keyfari again to get back to these settings": Entry(
            chinese: "隐藏后,再次打开 Keyfari 即可回到这里", japanese: "非表示のときは、Keyfari をもう一度開くとこの設定に戻れます"),
        "Troubleshooting": Entry(chinese: "问题排查", japanese: "トラブルシューティング"),
        "Diagnostic information": Entry(chinese: "诊断信息", japanese: "診断情報"),
        "Versions, displays, permissions and the names of changed settings, for a bug report": Entry(
            chinese: "版本、显示器、权限以及改动过的设置项名称,用于报告问题", japanese: "バージョン、ディスプレイ、権限、変更した設定の名前。不具合の報告用です"),
        "Copy": Entry(chinese: "复制", japanese: "コピー"),
        "Diagnostic information copied.": Entry(chinese: "诊断信息已复制。", japanese: "診断情報をコピーしました。"),
        "Language": Entry(chinese: "语言", japanese: "言語"),
        "Interface language": Entry(chinese: "界面语言", japanese: "表示言語"),
        "Takes effect immediately": Entry(chinese: "立即生效", japanese: "すぐに反映されます"),
        "System default": Entry(chinese: "跟随系统", japanese: "システムに合わせる"),
        "Ignored applications": Entry(chinese: "忽略的应用", japanese: "除外するアプリ"),
        "Sound effects": Entry(chinese: "音效", japanese: "効果音"),
        "Click sounds": Entry(chinese: "点击成功音", japanese: "クリック音"),
        "Play a sound after a successful click": Entry(chinese: "成功点击后播放提示音", japanese: "クリック成功時に音を鳴らす"),
        "Warning sounds": Entry(chinese: "警告音", japanese: "警告音"),
        "Play a sound for invalid or unavailable actions": Entry(chinese: "操作无效或无法执行时播放提示音", japanese: "無効または実行できない操作で音を鳴らす"),
        "Permissions": Entry(chinese: "权限", japanese: "アクセス権限"),
        "Accessibility permission": Entry(chinese: "辅助功能权限", japanese: "アクセシビリティ権限"),
        "Required for global shortcuts and controlling apps": Entry(
            chinese: "用于全局快捷键和控制其他应用", japanese: "グローバルショートカットとアプリの操作に必要です"),
        "Open System Settings…": Entry(chinese: "打开系统设置…", japanese: "システム設定を開く…"),
        "Usage statistics": Entry(chinese: "使用统计", japanese: "使用状況の統計"),
        "Enable usage statistics": Entry(chinese: "启用使用统计", japanese: "使用統計を有効にする"),
        "Counts stay on this Mac and are never sent anywhere": Entry(
            chinese: "统计数据仅保存在这台 Mac 上,不会发送到任何地方", japanese: "統計データはこの Mac にのみ保存され、外部に送信されません"),
        "Activity": Entry(chinese: "活动", japanese: "アクティビティ"),
        "Total clicks": Entry(chinese: "点击总数", japanese: "クリック合計"),
        "Current streak": Entry(chinese: "当前连续天数", japanese: "現在の連続日数"),
        "Longest streak": Entry(chinese: "最长连续天数", japanese: "最長連続日数"),
        "Active days": Entry(chinese: "活跃天数", japanese: "利用日数"),
        "Top apps": Entry(chinese: "常用应用", japanese: "よく使うアプリ"),
        "No clicks recorded yet": Entry(chinese: "还没有点击记录", japanese: "クリック記録はまだありません"),
        "%d clicks": Entry(chinese: "%d 次点击", japanese: "%d 回のクリック"),
        "Clear statistics": Entry(chinese: "清除统计数据", japanese: "統計データを消去"),
        "Statistics are off, so nothing is recorded. When they are on, only aggregate counts are stored, on this Mac.": Entry(
            chinese: "统计已关闭,不会记录任何内容。开启后仅在本机保存汇总数据。", japanese: "統計はオフのため、何も記録されません。オンにすると集計データのみがこの Mac に保存されます。"),
        "Time saved": Entry(chinese: "节省的时间", japanese: "節約した時間"),
        "Across %d keyboard actions": Entry(chinese: "来自 %d 次键盘操作", japanese: "キーボード操作 %d 回分"),
        "%d h %d min": Entry(chinese: "%d 小时 %d 分钟", japanese: "%d 時間 %d 分"),
        "%d min %d s": Entry(chinese: "%d 分 %d 秒", japanese: "%d 分 %d 秒"),
        "%d s": Entry(chinese: "%d 秒", japanese: "%d 秒"),
        "No applications are ignored": Entry(chinese: "没有忽略任何应用", japanese: "除外しているアプリはありません"),
        "Shortcuts do nothing while one of these applications is in front.": Entry(
            chinese: "这些应用在前台时,快捷键不起作用。",
            japanese: "これらのアプリが最前面にあるあいだ、ショートカットは動作しません。"
        ),
        "Add application": Entry(chinese: "添加应用", japanese: "アプリを追加"),
        "No other applications are running": Entry(chinese: "没有其他正在运行的应用", japanese: "ほかに実行中のアプリはありません"),
        "Remove": Entry(chinese: "移除", japanese: "削除"),

        // Hints
        "Appearance": Entry(chinese: "外观", japanese: "外観"),
        "Theme": Entry(chinese: "主题", japanese: "テーマ"),
        "Vivid": Entry(chinese: "多彩", japanese: "カラフル"),
        "Yellow": Entry(chinese: "黄色", japanese: "イエロー"),
        "Dark": Entry(chinese: "深色", japanese: "ダーク"),
        "Light": Entry(chinese: "浅色", japanese: "ライト"),
        "Liquid Glass": Entry(chinese: "液态玻璃", japanese: "リキッドグラス"),
        "Label size": Entry(chinese: "标签字号", japanese: "ラベルのサイズ"),
        "Corner radius": Entry(chinese: "圆角", japanese: "角の丸み"),
        "Label characters": Entry(chinese: "标签字符", japanese: "ラベルの文字"),
        "Letters used for labels. Home-row keys first keeps your fingers still.": Entry(
            chinese: "用于生成标签的字母。把基准键位的字母放在前面,手指移动最少。",
            japanese: "ラベルに使う文字です。ホームポジションのキーを先頭にすると指の移動が少なくなります。"
        ),
        "Needs at least %d different letters. Using %@ for now.": Entry(
            chinese: "至少需要 %d 个不同的字母。目前使用 %@。",
            japanese: "異なる文字が %d 個以上必要です。現在は %@ を使用しています。"
        ),
        "Behaviour": Entry(chinese: "行为", japanese: "動作"),
        "Keep labels stable": Entry(chinese: "保持标签稳定", japanese: "ラベルを固定する"),
        "An element keeps the label it had when you last clicked it": Entry(chinese: "点过的元素下次仍使用同一个标签", japanese: "一度クリックした要素には次回も同じラベルを付ける"),
        "Stable Labels": Entry(chinese: "固定标签", japanese: "固定ラベル"),
        "The same label for the same element, every time": Entry(chinese: "同一个元素每次都用同一个标签", japanese: "同じ要素にはいつも同じラベル"),
        "Stable labels": Entry(chinese: "固定标签", japanese: "固定ラベル"),
        "Remembered labels": Entry(chinese: "已记住的标签", japanese: "記憶したラベル"),
        "When you click something by its label, Keyfari remembers that label and shows it again next time. The most used come first. Type other letters into a field and press Return to choose the label yourself.":
            Entry(
                chinese: "用标签点击某个元素后,Keyfari 会记住这个标签,下次仍然显示它。列表按使用次数排序。在输入框里改成别的字母并按回车,就可以自己指定标签。",
                japanese: "ラベルで要素をクリックすると、Keyfari はそのラベルを記憶し、次回も同じものを表示します。一覧は使用回数の多い順です。欄に別の文字を入力して Return を押すと、自分でラベルを決められます。"
            ),
        "No labels remembered yet": Entry(chinese: "还没有记住任何标签", japanese: "記憶したラベルはまだありません"),
        "%d more labels are remembered": Entry(chinese: "另外还记住了 %d 个标签", japanese: "ほかに %d 個のラベルを記憶しています"),
        "Used once": Entry(chinese: "用过 1 次", japanese: "1 回使用"),
        "Used %d times": Entry(chinese: "用过 %d 次", japanese: "%d 回使用"),
        "Forget all labels": Entry(chinese: "清除全部标签", japanese: "すべてのラベルを消去"),
        "Chosen": Entry(chinese: "自定义", japanese: "指定済み"),
        "Save": Entry(chinese: "保存", japanese: "保存"),
        "%@ is not saved: a label may only use your label characters, %@.": Entry(
            chinese: "%@ 未保存:标签只能使用你设置的标签字符 %@。", japanese: "%@ は保存されません。ラベルに使えるのはラベルの文字 %@ だけです。"),
        "%@ is not saved: it would clash with the label %@ chosen for another element of this application.": Entry(
            chinese: "%@ 未保存:它与本应用中另一个元素的自定义标签 %@ 冲突。", japanese: "%@ は保存されません。このアプリの別の要素に指定したラベル %@ と衝突します。"),
        "Label all visible windows": Entry(chinese: "给所有可见窗口打标签", japanese: "見えているすべてのウインドウにラベルを付ける"),
        "Not only the focused one. Windows on other displays get longer labels": Entry(
            chinese: "不只是当前窗口。其他显示器上的窗口使用较长的标签", japanese: "フォーカスのあるウインドウ以外にも。ほかのディスプレイのウインドウには長めのラベルが付きます"),
        "Label the Dock": Entry(chinese: "给 Dock 打标签", japanese: "Dock にラベルを付ける"),
        "The icons in the Dock get labels while it shows": Entry(chinese: "程序坞显示时,里面的图标也有标签", japanese: "Dock が表示されているあいだ、アイコンにもラベルが付きます"),
        "Chain clicks": Entry(chinese: "连续点击", japanese: "連続クリック"),
        "Stay in the mode after a click, until Esc or a text field": Entry(
            chinese: "点击后不退出模式,直到按 Esc 或点到输入框", japanese: "クリック後もモードを続ける(Esc またはテキスト欄をクリックするまで)"),

        // Scrolling
        "Speed": Entry(chinese: "速度", japanese: "速度"),
        "Scroll speed": Entry(chinese: "滚动速度", japanese: "スクロール速度"),
        "Speed with Shift": Entry(chinese: "按住 Shift 时的倍数", japanese: "Shift を押したときの倍率"),
        "Direction": Entry(chinese: "方向", japanese: "方向"),
        "Reverse horizontal": Entry(chinese: "反转水平方向", japanese: "左右を反転"),
        "Reverse vertical": Entry(chinese: "反转垂直方向", japanese: "上下を反転"),
        "Keys": Entry(chinese: "按键", japanese: "キー"),
        "Arrow keys": Entry(chinese: "方向键", japanese: "矢印キー"),
        "Go to another scroll area, or scroll like the scroll keys": Entry(
            chinese: "切换滚动区域,或者像滚动键一样滚动", japanese: "スクロール領域を切り替えるか、スクロールキーと同じようにスクロール"),
        "Select": Entry(chinese: "选择区域", japanese: "領域を選択"),
        "Scroll": Entry(chinese: "滚动", japanese: "スクロール"),
        "Show scroll area numbers": Entry(chinese: "显示滚动区域编号", japanese: "スクロール領域の番号を表示"),
        "The number next to the outline, for jumping with 0–9": Entry(chinese: "边框旁的编号,用于按 0–9 直接跳转", japanese: "枠の横の番号。0–9 で移動するときに使います"),
        "Leave when idle": Entry(chinese: "空闲时退出", japanese: "操作がないとき終了"),
        "Never": Entry(chinese: "从不", japanese: "しない"),
        "Scroll keys": Entry(chinese: "滚动键", japanese: "スクロールキー"),
        "Four letters: left, down, up, right": Entry(chinese: "四个字母:左、下、上、右", japanese: "4 文字: 左・下・上・右"),
        "Half-page keys": Entry(chinese: "半页键", japanese: "半ページキー"),
        "Two letters: down, up": Entry(chinese: "两个字母:下、上", japanese: "2 文字: 下・上"),
        "The six letters must all be different, and G is taken. The standard keys are in use for now.": Entry(
            chinese: "六个字母必须互不相同,且不能使用 G。目前使用默认按键。", japanese: "6 つの文字はすべて異なる必要があり、G は使えません。現在は標準のキーを使用しています。"),
        "Scroll left, down, up, right": Entry(chinese: "向左、下、上、右滚动", japanese: "左・下・上・右にスクロール"),
        "Half a page down, up": Entry(chinese: "向下、向上半页", japanese: "半ページ下・上"),
        "Top  ·  Shift-G for the bottom": Entry(chinese: "到顶部  ·  Shift-G 到底部", japanese: "先頭へ  ·  Shift-G で末尾へ"),
        "Next scroll area  ·  0–9 to jump": Entry(chinese: "下一个滚动区  ·  0–9 直接跳转", japanese: "次のスクロール領域  ·  0–9 で移動"),

        // Desktops
        "Switch desktops": Entry(chinese: "切换桌面", japanese: "デスクトップを切り替える"),
        "Previous desktop": Entry(chinese: "上一个桌面", japanese: "前のデスクトップ"),
        "Go one desktop to the left": Entry(chinese: "切换到左边的桌面", japanese: "左のデスクトップへ移動"),
        "Next desktop": Entry(chinese: "下一个桌面", japanese: "次のデスクトップ"),
        "Go one desktop to the right": Entry(chinese: "切换到右边的桌面", japanese: "右のデスクトップへ移動"),
        "Record shortcut": Entry(chinese: "录制快捷键", japanese: "ショートカットを記録"),
        "Turn this shortcut off": Entry(chinese: "关闭这个快捷键", japanese: "このショートカットをオフにする"),
        "A shortcut that is unusable or already taken is switched off.": Entry(
            chinese: "无法使用或已被占用的快捷键会被关闭。", japanese: "使用できない、またはすでに使われているショートカットはオフになります。"),
        "A shortcut that macOS already uses to change desktops is left to macOS.": Entry(
            chinese: "与 macOS 切换桌面相同的快捷键会交给系统处理。", japanese: "macOS がデスクトップの切り替えに使っているショートカットは macOS に任せます。"),
        "Turn on “Move left a space” and “Move right a space” in System Settings > Keyboard > Keyboard Shortcuts > Mission Control.": Entry(
            chinese: "请在“系统设置 > 键盘 > 键盘快捷键 > 调度中心”中打开“向左移动一个空间”和“向右移动一个空间”。",
            japanese: "「システム設定 > キーボード > キーボードショートカット > Mission Control」で「左の操作スペースに移動」と「右の操作スペースに移動」をオンにしてください。"
        ),
        "Keyfari changes desktops by pressing the system's own shortcuts, so those have to stay on. When displays have separate Spaces, the display with the focused window changes.":
            Entry(
                chinese: "Keyfari 通过按下系统自带的快捷键来切换桌面,因此这些快捷键需要保持开启。开启“显示器具有单独的空间”时,切换的是当前窗口所在的显示器。",
                japanese: "Keyfari はシステム標準のショートカットを押してデスクトップを切り替えるため、それらをオンのままにしておく必要があります。「ディスプレイごとに個別の操作スペース」がオンの場合、フォーカスのあるウインドウのディスプレイが切り替わります。"
            ),

        "Mission Control": Entry(chinese: "调度中心", japanese: "Mission Control"),
        "Show labels automatically": Entry(chinese: "自动显示标签", japanese: "ラベルを自動的に表示"),
        "Label windows and desktops as soon as Mission Control opens": Entry(
            chinese: "打开调度中心时立即给窗口和桌面打标签", japanese: "Mission Control を開くとすぐにウインドウとデスクトップにラベルを付ける"),
        "Show or hide the labels in Mission Control": Entry(chinese: "在调度中心里显示或隐藏标签", japanese: "Mission Control でラベルを表示/非表示"),
        "Type a label to open its window or desktop": Entry(chinese: "输入标签即可打开对应的窗口或桌面", japanese: "ラベルを入力するとそのウインドウまたはデスクトップを開く"),
        "Leave Mission Control": Entry(chinese: "退出调度中心", japanese: "Mission Control を終了"),
        "With several displays, every display gets labels. Arrow keys and the system's shortcuts keep working.": Entry(
            chinese: "连接多台显示器时,每台显示器上都会显示标签。方向键和系统快捷键照常可用。",
            japanese: "複数のディスプレイがある場合、すべてのディスプレイにラベルが表示されます。矢印キーとシステムのショートカットはそのまま使えます。"
        ),

        // AI detection
        "On-screen text detection": Entry(chinese: "屏幕文字识别", japanese: "画面上のテキスト検出"),
        "Detect text": Entry(chinese: "识别文字", japanese: "テキストを検出"),
        "Off": Entry(chinese: "关闭", japanese: "オフ"),
        "When needed": Entry(chinese: "需要时", japanese: "必要なとき"),
        "Always": Entry(chinese: "始终", japanese: "常に"),
        "Reads the window's pixels on this Mac to label text the application does not expose. Nothing is saved or sent anywhere.": Entry(
            chinese: "在本机读取窗口画面,给应用没有暴露的文字打标签。不保存,也不发送任何内容。",
            japanese: "この Mac 上でウインドウの画面を読み取り、アプリが公開していないテキストにラベルを付けます。保存や送信は一切行いません。"
        ),
        "Icon buttons": Entry(chinese: "图标按钮", japanese: "アイコンボタン"),
        "Detect icon buttons": Entry(chinese: "识别图标按钮", japanese: "アイコンボタンを検出"),
        "Experimental. Labels small shapes that line up like a toolbar": Entry(
            chinese: "实验性功能。给像工具栏那样排成一排的小图形打标签", japanese: "実験的な機能。ツールバーのように並んだ小さな図形にラベルを付けます"),
        "Works from shapes alone, without a model: it misses icons that stand alone and may label decoration. It needs text detection to be on.":
            Entry(
                chinese: "只根据图形的形状判断,不使用模型:单独的图标识别不到,也可能把装饰图形当成按钮。需要先开启文字识别。",
                japanese: "モデルを使わず、図形の形だけで判断します。単独のアイコンは検出できず、装飾をボタンと見なすこともあります。テキスト検出がオンである必要があります。"),
        "Screen Recording permission": Entry(chinese: "屏幕录制权限", japanese: "画面収録の許可"),
        "Turn it on in System Settings, then restart Keyfari": Entry(
            chinese: "在系统设置里打开开关,然后重启 Keyfari", japanese: "システム設定でオンにしてから、Keyfari を再起動してください"),
        "Restart": Entry(chinese: "重启", japanese: "再起動"),
        "Granted": Entry(chinese: "已授权", japanese: "許可済み"),
        "Not granted": Entry(chinese: "未授权", japanese: "未許可"),
        "Request…": Entry(chinese: "申请…", japanese: "リクエスト…"),

        // Welcome guide
        "Welcome to Keyfari": Entry(chinese: "欢迎使用 Keyfari", japanese: "Keyfari へようこそ"),
        "Step %d of %d": Entry(chinese: "第 %d 步,共 %d 步", japanese: "ステップ %d / %d"),
        "Back": Entry(chinese: "上一步", japanese: "戻る"),
        "Continue": Entry(chinese: "继续", japanese: "続ける"),
        "Done": Entry(chinese: "完成", japanese: "完了"),
        "Keyfari reads what is on screen and clicks for you. macOS only lets it do that with the Accessibility permission.": Entry(
            chinese: "Keyfari 读取屏幕上的内容并替你点击。macOS 只在授予辅助功能权限后才允许这样做。",
            japanese: "Keyfari は画面上の内容を読み取り、代わりにクリックします。macOS がそれを許可するのは、アクセシビリティ権限があるときだけです。"),
        "In System Settings, switch Keyfari on in the list. Keyfari is not signed with an Apple Developer ID, so macOS asks for this again after every update.":
            Entry(
                chinese: "在系统设置的列表里打开 Keyfari 的开关。Keyfari 没有使用 Apple 开发者证书签名,所以每次更新后 macOS 都会要求重新授权。",
                japanese: "システム設定のリストで Keyfari をオンにしてください。Keyfari は Apple の Developer ID で署名されていないため、アップデートのたびに macOS が再度許可を求めます。"),
        "Three shortcuts do the work. Try them in any other application once this window is closed.": Entry(
            chinese: "三个快捷键就够用了。关闭这个窗口后,在任意其他应用里试试。", japanese: "3 つのショートカットで操作できます。このウインドウを閉じたら、ほかのアプリで試してみてください。"),
        "Every button, link and menu item gets a label. Type the label to click": Entry(
            chinese: "每个按钮、链接和菜单项都会出现标签,敲出标签即可点击", japanese: "ボタン、リンク、メニュー項目にラベルが付きます。ラベルを入力してクリック"),
        "Type part of an element's text, then Return": Entry(chinese: "输入元素上的部分文字,再按回车", japanese: "要素のテキストの一部を入力して Return"),
        "Scroll with the keyboard; Esc leaves": Entry(chinese: "用键盘滚动,按 Esc 退出", japanese: "キーボードでスクロール。Esc で終了"),
        "On the last letter of a label, hold Shift for a right click, Command for a double click, Option to only move the pointer. Esc always leaves.":
            Entry(
                chinese: "敲标签的最后一个字母时,按住 Shift 是右键,按住 Command 是双击,按住 Option 只移动指针。任何时候按 Esc 都可以退出。",
                japanese: "ラベルの最後の文字で Shift を押すと右クリック、Command でダブルクリック、Option でポインタの移動のみ。Esc でいつでも終了できます。"),
        "A few choices. All of them can be changed later in the settings.": Entry(
            chinese: "几个可选项,以后都可以在设置里修改。", japanese: "いくつかの選択項目です。あとで設定からすべて変更できます。"),
        "Optional. Lets Keyfari label text that applications do not expose": Entry(
            chinese: "可选。让 Keyfari 给应用没有暴露的文字打标签", japanese: "任意。アプリが公開していないテキストにもラベルを付けられます"),
        "Keyfari lives in the menu bar. Its menu opens the settings and this guide again.": Entry(
            chinese: "Keyfari 常驻菜单栏,从它的菜单可以打开设置,也可以再次打开这个引导。", japanese: "Keyfari はメニューバーに常駐します。メニューから設定やこのガイドをもう一度開けます。"),
        "Welcome Guide…": Entry(chinese: "使用引导…", japanese: "ガイド…"),
        "Welcome guide": Entry(chinese: "使用引导", japanese: "ガイド"),
        "Permissions, shortcuts and first choices, step by step": Entry(chinese: "一步步了解权限、快捷键和常用选项", japanese: "権限、ショートカット、最初の設定を順に案内"),
        "Show Guide": Entry(chinese: "打开引导", japanese: "ガイドを開く"),

        // Menu bar
        "Show Hints": Entry(chinese: "显示标签", japanese: "ヒントを表示"),
        "Scroll Mode": Entry(chinese: "滚动模式", japanese: "スクロールモード"),
        "Ignore %@": Entry(chinese: "忽略 %@", japanese: "%@ を除外"),
        "Settings…": Entry(chinese: "设置…", japanese: "設定…"),
        "Quit Keyfari": Entry(chinese: "退出 Keyfari", japanese: "Keyfari を終了"),

        // Search bar
        "Type to search": Entry(chinese: "输入以搜索", japanese: "入力して検索"),
        "1 match": Entry(chinese: "1 个匹配", japanese: "1 件"),
        "%d matches": Entry(chinese: "%d 个匹配", japanese: "%d 件"),
    ]
}

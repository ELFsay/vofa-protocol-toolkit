import QtQuick 2.12;
import MyModules 1.0

// VOFA+ 只读控件：以表格形式显示当前 configurable_engine.json 的协议概要
// 安装位置：VOFA+ 安装目录/plugins/widgets/VofaProtoView/VofaProtoView.qml
// 注意：控件代码改动后需要重启 VOFA+ 才生效；左侧控件栏缩略图用"刷新"按钮手动刷新
ResizableRectangle {
    id: root
    property string path: "VofaProtoView"
    color: "transparent"

    // 列宽（表头与数据行共用，保证对齐）
    property real wIdx: g_settings.applyHScale(26)
    property real wName: g_settings.applyHScale(150)
    property real wOff: g_settings.applyHScale(52)
    property real wType: g_settings.applyHScale(72)
    property real wEnd: g_settings.applyHScale(60)
    property real colGap: g_settings.applyHScale(8)
    property real tblWidth: wIdx + wName + wOff + wType + wEnd + colGap * 4   // 392

    width: g_settings.applyHScale(432)
    height: g_settings.applyVScale(286)
    // 最小尺寸：宽度按表格总宽算（内外边距 3+12 两侧），避免文字超出控件范围
    minimumWidth: g_settings.applyHScale(432)
    minimumHeight: g_settings.applyVScale(196)

    property string cfgName: "(未读取)"
    property string cfgHead: "-"
    property string cfgTail: "-"
    property int cfgFixed: 0
    property int cfgCh: 0
    property string cfgChk: "-"
    property string cfgErr: ""
    property string cfgTime: "-"
    property string cfgMore: ""
    property var chList: []
    property string chSig: ""
    property color fg: appTheme.bgColor.hsvValue > 0.5 ? "#202020" : "#e6e6e6"
    property color fg2: appTheme.bgColor.hsvValue > 0.5 ? "#606060" : "#a8a8a8"

    function reload() {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status !== 0 && xhr.status !== 200) {
                root.cfgErr = "读取失败（status " + xhr.status + "）：../../dataengines/configurable_engine.json";
                return;
            }
            var t = xhr.responseText;
            if (!t || t.length === 0) {
                root.cfgErr = "读不到内容：../../dataengines/configurable_engine.json";
                return;
            }
            if (t.indexOf("{") < 0) {
                root.cfgErr = "内容不是 JSON 文本（文件可能损坏）";
                return;
            }
            try {
                var o = JSON.parse(t);
                root.cfgName = o.name ? o.name : "(未命名)";
                var fr = o.framing ? o.framing : {};
                root.cfgHead = fr.header && fr.header.length > 0 ? fr.header : "-";
                root.cfgTail = fr.tail && fr.tail.length > 0 ? fr.tail : "-";
                root.cfgFixed = fr.fixed_length ? fr.fixed_length : 0;
                root.cfgChk = o.checksum && o.checksum.type ? o.checksum.type : "none";
                var fl = o.fields ? o.fields : [];
                root.cfgCh = fl.length;
                var cap = 12;                       // 最多显示 12 行，超出只提示
                root.cfgMore = fl.length > cap ? ("… 还有 " + (fl.length - cap) + " 个字段未显示") : "";

                var names = "";
                for (var i = 0; i < fl.length; i++)
                    names += "|" + fl[i].name + "@" + fl[i].offset + fl[i].type + fl[i].endian;
                if (names !== root.chSig) {
                    root.chSig = names;
                    var arr = [];
                    var n = Math.min(fl.length, cap);
                    for (var k = 0; k < n; k++) {
                        arr.push({
                                      "idx": k,
                                      "name": fl[k].name ? fl[k].name : "?",
                                      "off": fl[k].offset,
                                      "type": fl[k].type ? fl[k].type : "?",
                                      "end": fl[k].endian ? fl[k].endian : "-"
                                  });
                    }
                    root.chList = arr;
                }
                root.cfgTime = Qt.formatTime(new Date(), "HH:mm:ss");
                root.cfgErr = "";
            } catch (e) {
                root.cfgErr = "JSON 解析失败：" + e;
            }
        }
        xhr.open("GET", "../../dataengines/configurable_engine.json", true);
        xhr.send();
    }

    Component {
        id: cellComp
        Text {
            property string txt: ""
            property real wid: 0
            property color col: root.fg
            width: wid
            text: txt
            color: col
            font.pixelSize: g_settings.applyHScale(12)
            elide: Text.ElideRight
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        anchors.margins: g_settings.applyHScale(3)
        color: appTheme.bgColor
        border.color: appTheme.lineColor
        border.width: 1
        radius: g_settings.applyHScale(8)
        clip: true                                  // 内容永不溢出控件范围

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: g_settings.applyHScale(12)
            spacing: g_settings.applyVScale(4)

            Text {
                text: "自定义协议 · " + root.cfgName
                color: appTheme.mainColor
                font.pixelSize: g_settings.applyHScale(15)
                font.bold: true
                elide: Text.ElideRight
                width: root.tblWidth
            }
            Text {
                width: root.tblWidth
                text: "帧头 " + root.cfgHead + "   帧尾 " + root.cfgTail + "   定长 " + root.cfgFixed
                      + "   通道数 " + root.cfgCh + "   校验 " + root.cfgChk
                color: root.fg
                font.pixelSize: g_settings.applyHScale(12)
                elide: Text.ElideRight
            }
            Text {
                visible: root.cfgErr.length > 0
                width: root.tblWidth
                text: root.cfgErr
                color: "#d05000"
                font.pixelSize: g_settings.applyHScale(12)
                wrapMode: Text.WordWrap
            }

            Row {
                spacing: root.colGap
                Loader { sourceComponent: cellComp; onLoaded: { item.txt = "#";      item.wid = root.wIdx;  item.col = root.fg2 } }
                Loader { sourceComponent: cellComp; onLoaded: { item.txt = "名称";   item.wid = root.wName; item.col = root.fg2 } }
                Loader { sourceComponent: cellComp; onLoaded: { item.txt = "偏移";   item.wid = root.wOff;  item.col = root.fg2 } }
                Loader { sourceComponent: cellComp; onLoaded: { item.txt = "类型";   item.wid = root.wType; item.col = root.fg2 } }
                Loader { sourceComponent: cellComp; onLoaded: { item.txt = "字节序"; item.wid = root.wEnd;  item.col = root.fg2 } }
            }
            Rectangle {
                width: root.tblWidth
                height: 1
                color: appTheme.lineColor
            }

            Column {
                spacing: g_settings.applyVScale(2)
                Repeater {
                    model: root.chList
                    delegate: Row {
                        spacing: root.colGap
                        Loader { sourceComponent: cellComp; onLoaded: { item.txt = "" + modelData.idx;  item.wid = root.wIdx } }
                        Loader { sourceComponent: cellComp; onLoaded: { item.txt = modelData.name;     item.wid = root.wName } }
                        Loader { sourceComponent: cellComp; onLoaded: { item.txt = "@" + modelData.off; item.wid = root.wOff } }
                        Loader { sourceComponent: cellComp; onLoaded: { item.txt = modelData.type;     item.wid = root.wType } }
                        Loader { sourceComponent: cellComp; onLoaded: { item.txt = modelData.end;      item.wid = root.wEnd } }
                    }
                }
            }

            Text {
                visible: root.cfgMore.length > 0
                text: root.cfgMore
                color: root.fg2
                font.pixelSize: g_settings.applyHScale(11)
            }
            Text {
                text: "读取于 " + root.cfgTime
                color: root.fg2
                font.pixelSize: g_settings.applyHScale(11)
            }
        }
    }

    MyMenu {
        id: menu
        DeleteMenuItem {
            target: root
        }
        MyMenuItem {
            text: qsTr("立即刷新")
            text_center: true
            onTriggered: root.reload()
        }
    }

    Connections {
        target: root.mouse
        onClicked: {
            if (mouse.button === Qt.RightButton)
                menu.popup();
            else
                root.reload();
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.reload()
    }

    Component.onCompleted: reload()

    function get_widget_ctx() {
        var ctx = {
            'path': path,
            'ctx': {
                '.': { 'ctx': get_ctx() }
            }
        };
        return ctx;
    }

    function set_widget_ctx(ctx) {
        __set_ctx__(root, ctx.ctx);
    }
}

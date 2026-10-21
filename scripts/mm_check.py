import io
import os
import sys
from xml.dom import minidom


def die(msg):
    print('MM_CHECK FAIL: ' + msg)
    sys.exit(1)


def check(cond, msg):
    if not cond:
        die(msg)


def texts_of(nodes, attr):
    return [n.getAttribute(attr) for n in nodes]


EXPECTED = [
    'MdConvert 对账样本',
    '前言段落，含 粗体、斜体、删除、行内码、链接。',
    '列表',
    '无序一',
    '无序二',
    '有序嵌套',
    '第二项',
    '代码',
    '[ts] const s: string = "hello";',
    '表格',
    '表格：名称 | 数量 | 备注',
    '甲 | 1 | 左',
    '乙 | 2 | 右',
    '引用一段',
    '尾段 外部 图。',
]

FIRST_LEVEL_POSITIONS = ['right', 'right', 'left', 'left']


def main():
    if len(sys.argv) < 2:
        die('usage: mm_check.py <golden_dir>')
    d = sys.argv[1]
    mm_path = os.path.join(d, 'mdc_sample.mm')
    opml_path = os.path.join(d, 'mdc_sample.opml')
    for p in (mm_path, opml_path):
        if not os.path.isfile(p):
            die('missing file: ' + p)
    with io.open(mm_path, 'r', encoding='utf-8') as f:
        mm_raw = f.read()
    with io.open(opml_path, 'r', encoding='utf-8') as f:
        opml_raw = f.read()

    mm_doc = minidom.parseString(mm_raw.encode('utf-8'))
    opml_doc = minidom.parseString(opml_raw.encode('utf-8'))

    map_el = mm_doc.documentElement
    check(map_el.tagName == 'map', 'mm root tag is not map')
    check(map_el.getAttribute('version') == '1.0.1', 'mm version != 1.0.1')

    mm_nodes = mm_doc.getElementsByTagName('node')
    check(len(mm_nodes) == 15, 'mm node count %d != 15' % len(mm_nodes))
    mm_texts = texts_of(mm_nodes, 'TEXT')
    check(sorted(mm_texts) == sorted(EXPECTED),
          'mm node text set mismatch: %r' % mm_texts)
    check(mm_nodes[0].getAttribute('TEXT') == 'MdConvert 对账样本', 'mm root text mismatch')
    check(not mm_nodes[0].hasAttribute('POSITION'), 'mm root must not carry POSITION')
    first_level = [n for n in mm_nodes[0].childNodes if n.nodeType == n.ELEMENT_NODE]
    check(len(first_level) == 4, 'mm first-level count %d != 4' % len(first_level))
    positions = [n.getAttribute('POSITION') for n in first_level]
    check(positions == FIRST_LEVEL_POSITIONS,
          'mm POSITION sequence %r != %r' % (positions, FIRST_LEVEL_POSITIONS))

    opml_el = opml_doc.documentElement
    check(opml_el.tagName == 'opml', 'opml root tag is not opml')
    check(opml_el.getAttribute('version') == '2.0', 'opml version != 2.0')
    titles = opml_doc.getElementsByTagName('title')
    check(len(titles) == 1, 'opml title count != 1')
    check(titles[0].firstChild is not None and titles[0].firstChild.data == 'MdConvert 对账样本',
          'opml head title mismatch')
    outlines = opml_doc.getElementsByTagName('outline')
    check(len(outlines) == 15, 'opml outline count %d != 15' % len(outlines))
    opml_texts = texts_of(outlines, 'text')
    check(sorted(opml_texts) == sorted(EXPECTED),
          'opml outline text set mismatch: %r' % opml_texts)
    body = opml_doc.getElementsByTagName('body')[0]
    body_outlines = [n for n in body.childNodes if n.nodeType == n.ELEMENT_NODE and n.tagName == 'outline']
    check(len(body_outlines) == 1, 'opml body must hold exactly one root outline')

    print('MM_CHECK PASS: mm nodes=15 opml outlines=15 positions=%s' % ','.join(positions))


if __name__ == '__main__':
    main()

import re
import sys
import zipfile
from pathlib import Path
from xml.dom import minidom


EXPECTED_NAMES = [
    '[Content_Types].xml',
    '_rels/.rels',
    'word/document.xml',
    'word/styles.xml',
    'word/numbering.xml',
    'word/_rels/document.xml.rels',
]

PROBES = [
    'MdConvert 对账样本',
    '前言段落',
    '无序一',
    '有序嵌套',
    'console.log',
    'const s: string = "hello";',
    '引用一段',
    '继续引用',
    'img.png',
]

REL_PROBES = [
    'https://example.com/a',
    'https://example.com/(x)',
]


def main() -> int:
    if len(sys.argv) != 2:
        print('usage: py -3 scripts/docx_check.py <dump_dir>')
        return 2
    d = Path(sys.argv[1])
    p = d / 'mdc_sample.docx'
    if not p.exists():
        print('missing mdc_sample.docx')
        return 2
    z = zipfile.ZipFile(p)
    bad = z.testzip()
    if bad is not None:
        print('CRC FAIL at %s' % bad)
        return 1
    names = z.namelist()
    if sorted(names) != sorted(EXPECTED_NAMES):
        print('unexpected zip entries: %s' % names)
        return 1
    for n in names:
        info = z.getinfo(n)
        if info.compress_type != zipfile.ZIP_STORED:
            print('entry not STOREd: %s' % n)
            return 1
        if not (info.flag_bits & 0x800):
            print('entry missing UTF-8 flag: %s' % n)
            return 1
        minidom.parseString(z.read(n))
    doc = z.read('word/document.xml').decode('utf-8')
    rels = z.read('word/_rels/document.xml.rels').decode('utf-8')
    num = z.read('word/numbering.xml').decode('utf-8')
    styles = z.read('word/styles.xml').decode('utf-8')
    ct = z.read('[Content_Types].xml').decode('utf-8')
    root_rels = z.read('_rels/.rels').decode('utf-8')

    used_ids = set(re.findall(r'<w:hyperlink r:id="([^"]+)"', doc))
    rel_ids = set(re.findall(r'Id="([^"]+)"', rels))
    if not used_ids <= rel_ids:
        print('hyperlink ids not in rels: %s' % (used_ids - rel_ids))
        return 1
    if 'Id="rId1"' not in rels or 'Target="styles.xml"' not in rels:
        print('styles rel missing')
        return 1
    if 'Id="rId2"' not in rels or 'Target="numbering.xml"' not in rels:
        print('numbering rel missing')
        return 1
    if 'TargetMode="External"' not in rels:
        print('external hyperlink rel missing')
        return 1
    if 'officeDocument' not in root_rels or 'word/document.xml' not in root_rels:
        print('root rel broken')
        return 1
    for part in ('/word/document.xml', '/word/styles.xml', '/word/numbering.xml'):
        if part not in ct:
            print('content type missing: %s' % part)
            return 1
    for style in ('Normal', 'Heading1', 'Heading6', 'MdcCode', 'MdcQuote',
                  'ListParagraph', 'TableGrid'):
        if 'w:styleId="%s"' % style not in styles:
            print('style missing: %s' % style)
            return 1
    for frag in ('<w:abstractNum w:abstractNumId="0"', '<w:abstractNum w:abstractNumId="1"',
                 '<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>',
                 '<w:numFmt w:val="bullet"/>', '<w:numFmt w:val="decimal"/>'):
        if frag not in num:
            print('numbering frag missing: %s' % frag)
            return 1
    if '<w:startOverride w:val="1"/>' not in num:
        print('ordered startOverride missing')
        return 1
    for probe in PROBES:
        if probe not in doc:
            print('document probe missing: %s' % probe)
            return 1
    for probe in REL_PROBES:
        if probe not in rels:
            print('rels probe missing: %s' % probe)
            return 1
    text = re.sub(r'<[^>]+>', '', doc)
    for probe in ('无序二', '有序嵌套', '第二项', '甲', '乙', '左', '右'):
        if probe not in text:
            print('body text probe missing: %s' % probe)
            return 1
    for frag in ('<w:tblHeader/>', '</w:tbl>', '<w:pgSz w:w="11906" w:h="16838"/>',
                 '<w:pStyle w:val="MdcCode"/>', '<w:hyperlink '):
        if frag not in doc:
            print('document frag missing: %s' % frag)
            return 1
    print('DOCX_CHECK PASS')
    return 0


if __name__ == '__main__':
    sys.exit(main())

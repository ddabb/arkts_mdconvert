import json
import sys
from pathlib import Path

import yaml


def alnum_of(s: str) -> str:
    out = []
    for ch in s:
        o = ord(ch)
        if 48 <= o <= 57 or 65 <= o <= 90 or 97 <= o <= 122 or 0x4E00 <= o <= 0x9FFF:
            out.append(ch)
    return ''.join(out)


def is_subseq(needle: str, hay: str) -> bool:
    pos = 0
    for ch in hay:
        if pos < len(needle) and ch == needle[pos]:
            pos += 1
    return pos == len(needle)


def collect_strings(obj, out):
    if isinstance(obj, bool):
        return
    if isinstance(obj, str):
        out.append(obj)
    elif isinstance(obj, int):
        out.append(str(obj))
    elif isinstance(obj, dict):
        for v in obj.values():
            collect_strings(v, out)
    elif isinstance(obj, list):
        for v in obj:
            collect_strings(v, out)


def find_all(obj, type_name, out):
    if isinstance(obj, dict):
        if obj.get('type') == type_name:
            out.append(obj)
        for v in obj.values():
            find_all(v, type_name, out)
    elif isinstance(obj, list):
        for v in obj:
            find_all(v, type_name, out)


def main() -> int:
    if len(sys.argv) != 2:
        print('usage: py -3 scripts/cross_check.py <dump_dir>')
        return 2
    d = Path(sys.argv[1])
    src = (d / 'mdc_source.md').read_text(encoding='utf-8')
    flat_j = json.loads((d / 'mdc_flat.json').read_text(encoding='utf-8'))
    tree_j = json.loads((d / 'mdc_tree.json').read_text(encoding='utf-8'))
    flat_y = yaml.safe_load((d / 'mdc_flat.yaml').read_text(encoding='utf-8'))
    tree_y = yaml.safe_load((d / 'mdc_tree.yaml').read_text(encoding='utf-8'))
    checks = []

    assert flat_y == flat_j, 'flat yaml != flat json'
    assert tree_y == tree_j, 'tree yaml != tree json'
    checks.append('yaml.safe_load == json.loads deep equal (flat + tree)')

    headings = []
    find_all(flat_j, 'heading', headings)
    assert [h['level'] for h in headings] == [1, 2, 2, 2], 'heading levels'

    all_code = []
    find_all(flat_j, 'code', all_code)
    block_code = [c for c in all_code if 'lang' in c]
    inline_code = [c for c in all_code if 'lang' not in c]
    assert len(block_code) == 1 and block_code[0]['lang'] == 'ts', 'block code'
    assert 'console.log(s);' in block_code[0]['text'], 'code text'
    assert len(inline_code) == 1 and inline_code[0]['text'] == '行内码', 'inline code'
    checks.append('code block + inline code')

    tables = []
    find_all(flat_j, 'table', tables)
    assert len(tables) == 1, 'table count'
    t = tables[0]
    assert t['aligns'] == ['none', 'left', 'right'], 'aligns'
    assert len(t['rows']) == 3, 'table rows'
    header = []
    collect_strings(t['rows'][0], header)
    assert '名称' in header and '数量' in header and '备注' in header, 'header cells'
    checks.append('table aligns + header')

    lists = []
    find_all(flat_j, 'list', lists)
    ordered = [l for l in lists if l['ordered']]
    unordered = [l for l in lists if not l['ordered']]
    assert len(ordered) == 1 and len(unordered) == 1, 'lists'
    assert [i['num'] for i in ordered[0]['items']] == [1, 2], 'ordered nums'
    checks.append('ordered/unordered lists + nums')

    quotes = []
    find_all(flat_j, 'quote', quotes)
    assert len(quotes) == 1 and len(quotes[0]['blocks']) == 1, 'quote'
    hrs = []
    find_all(flat_j, 'hr', hrs)
    assert len(hrs) == 1, 'hr'
    checks.append('quote + hr')

    strs = []
    collect_strings(flat_j, strs)
    joined = '\n'.join(strs)
    for probe in ['https://example.com/a', 'https://example.com/(x)', 'img.png',
                  '对账样本', '前言段落', '有序嵌套', '引用一段', '粗体', '删除', '尾段']:
        assert probe in joined, 'missing probe: ' + probe
    checks.append('content probes (links/image/CJK/inline styles)')

    assert is_subseq(alnum_of(src), alnum_of(joined)), 'lossless subsequence failed'
    checks.append('python-side lossless subsequence')

    assert tree_j['blocks'] == [], 'preamble should be empty'
    secs = tree_j['sections']
    assert len(secs) == 1 and secs[0]['level'] == 1, 'root section'
    assert [c['level'] for c in secs[0]['children']] == [2, 2, 2], 'children levels'
    code_sec_blocks = []
    find_all(secs[0]['children'][1]['blocks'], 'code', code_sec_blocks)
    assert len([c for c in code_sec_blocks if 'lang' in c]) == 1, 'code in section'
    checks.append('tree sections structure')

    print('CROSS_CHECK PASS')
    for c in checks:
        print('  -', c)
    return 0


if __name__ == '__main__':
    sys.exit(main())

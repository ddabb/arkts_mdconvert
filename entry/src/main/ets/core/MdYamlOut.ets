import { JArr, JBool, JObj, JPair, JStr, JNum, JVal, MdToJson } from './MdJsonOut';
import { MdInlineParser } from './MdInlineParser';

export class YWriter {
  static write(root: JVal): string {
    const lines: string[] = [];
    if (root instanceof JObj) {
      for (const p of root.pairs) {
        YWriter.emitPair(p, 0, lines);
      }
    }
    return lines.length == 0 ? '' : lines.join('\n') + '\n';
  }

  static pad(indent: number): string {
    let out: string = '';
    for (let i: number = 0; i < indent; i += 1) {
      out += '  ';
    }
    return out;
  }

  static emitPair(p: JPair, indent: number, lines: string[]): void {
    const pad: string = YWriter.pad(indent);
    const val: JVal = p.val;
    if (val instanceof JObj) {
      if (val.pairs.length == 0) {
        lines.push(pad + p.key + ': {}');
        return;
      }
      lines.push(pad + p.key + ':');
      for (const inner of val.pairs) {
        YWriter.emitPair(inner, indent + 1, lines);
      }
      return;
    }
    if (val instanceof JArr) {
      if (val.items.length == 0) {
        lines.push(pad + p.key + ': []');
        return;
      }
      lines.push(pad + p.key + ':');
      YWriter.emitArr(val, indent + 1, lines);
      return;
    }
    if (val instanceof JStr) {
      YWriter.emitScalarPair(p.key, val.s, indent, lines);
      return;
    }
    if (val instanceof JNum) {
      lines.push(pad + p.key + ': ' + val.n.toString());
      return;
    }
    if (val instanceof JBool) {
      lines.push(pad + p.key + ': ' + (val.b ? 'true' : 'false'));
      return;
    }
    lines.push(pad + p.key + ': null');
  }

  static emitScalarPair(key: string, s: string, indent: number, lines: string[]): void {
    const pad: string = YWriter.pad(indent);
    if (s.indexOf('\n') >= 0) {
      let body: string = s;
      let chomp: string = '|-';
      if (s.charAt(s.length - 1) == '\n') {
        body = s.substring(0, s.length - 1);
        chomp = '|';
        if (body.charAt(body.length - 1) == '\n') {
          chomp = '|+';
        }
      }
      lines.push(pad + key + ': ' + chomp);
      const parts: string[] = body.split('\n');
      for (const line of parts) {
        if (line.length == 0) {
          lines.push('');
        } else {
          lines.push(YWriter.pad(indent + 1) + line);
        }
      }
      return;
    }
    lines.push(pad + key + ': ' + YWriter.scalar(s));
  }

  static emitArr(arr: JArr, indent: number, lines: string[]): void {
    for (const item of arr.items) {
      if (item instanceof JObj) {
        YWriter.emitArrItemObj(item, indent, lines);
      } else if (item instanceof JArr) {
        lines.push(YWriter.pad(indent) + '-');
        YWriter.emitArr(item, indent + 1, lines);
      } else if (item instanceof JStr) {
        lines.push(YWriter.pad(indent) + '- ' + YWriter.scalar(item.s));
      } else if (item instanceof JNum) {
        lines.push(YWriter.pad(indent) + '- ' + item.n.toString());
      } else if (item instanceof JBool) {
        lines.push(YWriter.pad(indent) + '- ' + (item.b ? 'true' : 'false'));
      }
    }
  }

  static emitArrItemObj(o: JObj, indent: number, lines: string[]): void {
    if (o.pairs.length == 0) {
      lines.push(YWriter.pad(indent) + '- {}');
      return;
    }
    YWriter.emitPairDash(o.pairs[0], indent, lines);
    for (let i: number = 1; i < o.pairs.length; i += 1) {
      YWriter.emitPair(o.pairs[i], indent + 1, lines);
    }
  }

  static emitPairDash(p: JPair, indent: number, lines: string[]): void {
    const pad: string = YWriter.pad(indent);
    const val: JVal = p.val;
    if (val instanceof JObj) {
      if (val.pairs.length == 0) {
        lines.push(pad + '- ' + p.key + ': {}');
        return;
      }
      lines.push(pad + '- ' + p.key + ':');
      for (const inner of val.pairs) {
        YWriter.emitPair(inner, indent + 2, lines);
      }
      return;
    }
    if (val instanceof JArr) {
      if (val.items.length == 0) {
        lines.push(pad + '- ' + p.key + ': []');
        return;
      }
      lines.push(pad + '- ' + p.key + ':');
      YWriter.emitArr(val, indent + 2, lines);
      return;
    }
    if (val instanceof JStr) {
      if (val.s.indexOf('\n') >= 0) {
        const rest: string[] = [];
        YWriter.emitScalarPair(p.key, val.s, indent + 1, rest);
        if (rest.length > 0) {
          rest[0] = pad + '-' + rest[0].substring(YWriter.pad(indent + 1).length);
          for (const line of rest) {
            lines.push(line);
          }
          return;
        }
      }
      lines.push(pad + '- ' + p.key + ': ' + YWriter.scalar(val.s));
      return;
    }
    if (val instanceof JNum) {
      lines.push(pad + '- ' + p.key + ': ' + val.n.toString());
      return;
    }
    if (val instanceof JBool) {
      lines.push(pad + '- ' + p.key + ': ' + (val.b ? 'true' : 'false'));
      return;
    }
    lines.push(pad + '- ' + p.key + ': null');
  }

  static scalar(s: string): string {
    if (YWriter.needsQuote(s)) {
      return YWriter.doubleQuote(s);
    }
    return s;
  }

  static needsQuote(s: string): boolean {
    if (s.length == 0) {
      return true;
    }
    if (s.charAt(0) == ' ' || s.charAt(s.length - 1) == ' ') {
      return true;
    }
    const first: string = s.charAt(0);
    if ('-?:,[]{}#&*!|>\'"%@`'.indexOf(first) >= 0) {
      return true;
    }
    if (s.indexOf(': ') >= 0 || s.indexOf(' #') >= 0 || s.charAt(s.length - 1) == ':') {
      return true;
    }
    for (let i: number = 0; i < s.length - 1; i += 1) {
      if (s.charAt(i) == ':' && s.charCodeAt(i + 1) >= 48 && s.charCodeAt(i + 1) <= 57) {
        return true;
      }
    }
    const low: string = s.toLowerCase();
    if (low == 'true' || low == 'false' || low == 'null' || low == 'yes' || low == 'no' ||
      low == 'on' || low == 'off' || s == '~') {
      return true;
    }
    const c0: number = s.charCodeAt(0);
    if ((c0 >= 48 && c0 <= 57) || (first == '-' && s.length > 1 && s.charCodeAt(1) >= 48 && s.charCodeAt(1) <= 57)) {
      return true;
    }
    if (s.indexOf('\t') >= 0 || s.indexOf('\r') >= 0) {
      return true;
    }
    return false;
  }

  static doubleQuote(s: string): string {
    let out: string = '"';
    for (let i: number = 0; i < s.length; i += 1) {
      const c: string = s.charAt(i);
      const code: number = c.charCodeAt(0);
      if (c == '"') {
        out += '\\"';
      } else if (c == '\\') {
        out += '\\\\';
      } else if (code == 10) {
        out += '\\n';
      } else if (code == 13) {
        out += '\\r';
      } else if (code == 9) {
        out += '\\t';
      } else if (code < 32) {
        out += '\\u00';
        const hex: string = code.toString(16);
        out += hex.length < 2 ? '0' + hex : hex;
      } else {
        out += c;
      }
    }
    return out + '"';
  }
}

export class MdToYaml {
  static flat(src: string): string {
    return YWriter.write(MdToJson.flatDoc(MdInlineParser.parseFull(src)));
  }

  static tree(src: string): string {
    return YWriter.write(MdToJson.treeDoc(MdInlineParser.parseFull(src)));
  }
}

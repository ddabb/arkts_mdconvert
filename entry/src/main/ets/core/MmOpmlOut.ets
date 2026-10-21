import { MindNode, MindTreeBuilder } from './MindmapTree';
import { MdToDocx } from './DocxOut';

export class MdToMm {
  static mm(src: string): string {
    return MdToMm.mmTree(MindTreeBuilder.buildSrc(src, 0));
  }

  static mmTree(root: MindNode): string {
    const sb: string[] = [];
    sb.push('<map version="1.0.1">');
    sb.push('\n');
    MdToMm.nodeXml(root, 1, '', sb);
    sb.push('</map>');
    sb.push('\n');
    return sb.join('');
  }

  static nodeXml(node: MindNode, depth: number, position: string, sb: string[]): void {
    sb.push(MdToMm.indent(depth));
    sb.push('<node TEXT="');
    sb.push(MdToDocx.escAttr(node.text));
    sb.push('"');
    if (position.length > 0) {
      sb.push(' POSITION="');
      sb.push(position);
      sb.push('"');
    }
    if (node.children.length == 0) {
      sb.push('/>');
      sb.push('\n');
      return;
    }
    sb.push('>');
    sb.push('\n');
    const rightCount: number = Math.ceil(node.children.length / 2);
    for (let i: number = 0; i < node.children.length; i += 1) {
      let pos: string = '';
      if (depth == 1) {
        pos = i < rightCount ? 'right' : 'left';
      }
      MdToMm.nodeXml(node.children[i], depth + 1, pos, sb);
    }
    sb.push(MdToMm.indent(depth));
    sb.push('</node>');
    sb.push('\n');
  }

  static indent(depth: number): string {
    let out: string = '';
    for (let i: number = 0; i < depth; i += 1) {
      out += '  ';
    }
    return out;
  }
}

export class MdToOpml {
  static opml(src: string): string {
    return MdToOpml.opmlTree(MindTreeBuilder.buildSrc(src, 0));
  }

  static opmlTree(root: MindNode): string {
    const sb: string[] = [];
    sb.push('<?xml version="1.0" encoding="UTF-8"?>');
    sb.push('\n');
    sb.push('<opml version="2.0">');
    sb.push('\n');
    sb.push('  <head>');
    sb.push('\n');
    sb.push('    <title>');
    sb.push(MdToDocx.esc(root.text));
    sb.push('</title>');
    sb.push('\n');
    sb.push('  </head>');
    sb.push('\n');
    sb.push('  <body>');
    sb.push('\n');
    MdToOpml.outlineXml(root, 2, sb);
    sb.push('  </body>');
    sb.push('\n');
    sb.push('</opml>');
    sb.push('\n');
    return sb.join('');
  }

  static outlineXml(node: MindNode, depth: number, sb: string[]): void {
    sb.push(MdToOpml.indent(depth));
    sb.push('<outline text="');
    sb.push(MdToDocx.escAttr(node.text));
    sb.push('"');
    if (node.children.length == 0) {
      sb.push('/>');
      sb.push('\n');
      return;
    }
    sb.push('>');
    sb.push('\n');
    for (const child of node.children) {
      MdToOpml.outlineXml(child, depth + 1, sb);
    }
    sb.push(MdToOpml.indent(depth));
    sb.push('</outline>');
    sb.push('\n');
  }

  static indent(depth: number): string {
    let out: string = '';
    for (let i: number = 0; i < depth; i += 1) {
      out += '  ';
    }
    return out;
  }
}

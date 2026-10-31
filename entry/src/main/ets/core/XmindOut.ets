import { MindNode, MindTreeBuilder } from './MindmapTree';
import { ZipWriter } from './ZipWriter';

class XidCounter {
  n: number = 0;
}

export class MdToXmind {
  static xmind(src: string): Uint8Array {
    const root: MindNode = MindTreeBuilder.buildSrc(src, 0);
    MindTreeBuilder.assignPaths(root);
    return MdToXmind.xmindTree(root);
  }

  static xmindTree(root: MindNode): Uint8Array {
    const counter: XidCounter = new XidCounter();
    const topic: string = MdToXmind.topicJson(root, counter);
    const contentJson: string = '[{"id":"s1","class":"sheet","title":"Sheet 1","rootTopic":' +
      topic + '}]';
    const metadataJson: string = '{"creator":{"name":"MdConvert","version":"1.0.2"}}';
    const manifestJson: string = '{"file-entries":{"content.json":{},"metadata.json":{}}}';
    const zip: ZipWriter = new ZipWriter();
    zip.add('content.json', contentJson);
    zip.add('metadata.json', metadataJson);
    zip.add('manifest.json', manifestJson);
    return zip.bytes();
  }

  static topicJson(node: MindNode, counter: XidCounter): string {
    counter.n += 1;
    const sb: string[] = ['{"id":"t', counter.n.toString(), '","class":"topic","title":"',
      MdToXmind.escJson(node.text), '"'];
    if (node.path == '0') {
      sb.push(',"structureClass":"org.xmind.ui.logic.right"');
    }
    if (node.children.length > 0) {
      sb.push(',"children":{"attached":[');
      for (let i: number = 0; i < node.children.length; i += 1) {
        if (i > 0) {
          sb.push(',');
        }
        sb.push(MdToXmind.topicJson(node.children[i], counter));
      }
      sb.push(']}');
    }
    sb.push('}');
    return sb.join('');
  }

  static escJson(s: string): string {
    let out: string = '';
    for (let i: number = 0; i < s.length; i += 1) {
      const c: string = s.charAt(i);
      const code: number = s.charCodeAt(i);
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
      } else if (code == 8) {
        out += '\\b';
      } else if (code == 12) {
        out += '\\f';
      } else if (code < 32) {
        const hex: string = code.toString(16).padStart(2, '0').toUpperCase();
        out += '\\u00' + hex;
      } else {
        out += c;
      }
    }
    return out;
  }
}

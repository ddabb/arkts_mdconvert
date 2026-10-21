export class MindTheme {
  readonly key: string;
  readonly bg: string;
  readonly rootFill: string;
  readonly rootText: string;
  readonly nodeFill: string;
  readonly nodeText: string;
  readonly nodeStroke: string;
  readonly branches: string[];

  constructor(key: string, bg: string, rootFill: string, rootText: string,
    nodeFill: string, nodeText: string, nodeStroke: string, branches: string[]) {
    this.key = key;
    this.bg = bg;
    this.rootFill = rootFill;
    this.rootText = rootText;
    this.nodeFill = nodeFill;
    this.nodeText = nodeText;
    this.nodeStroke = nodeStroke;
    this.branches = branches;
  }

  static fresh(): MindTheme {
    return new MindTheme('fresh', '#F8FAFC', '#0284C7', '#FFFFFF', '#FFFFFF',
      '#1E293B', '#CBD5E1',
      ['#0284C7', '#14B8A6', '#8B5CF6', '#F59E0B', '#EC4899', '#10B981']);
  }

  static journal(): MindTheme {
    return new MindTheme('journal', '#FBF3E4', '#B45309', '#FFFDF6', '#FFFDF6',
      '#57351F', '#E4CFA8',
      ['#C2410C', '#B45309', '#0F766E', '#7C3AED', '#BE185D', '#4D7C0F']);
  }

  static dark(): MindTheme {
    return new MindTheme('dark', '#0F172A', '#0284C7', '#FFFFFF', '#1E293B',
      '#E2E8F0', '#334155',
      ['#38BDF8', '#2DD4BF', '#A78BFA', '#FBBF24', '#F472B6', '#4ADE80']);
  }

  static all(): MindTheme[] {
    return [MindTheme.fresh(), MindTheme.journal(), MindTheme.dark()];
  }

  branchColor(depth: number): string {
    return this.branches[(depth - 1) % this.branches.length];
  }
}

/** One row of `bd list --json`, the fields the pane draws. */
export type BeadsIssue = {
  id: string
  title: string
  status: string
  priority: number
  issue_type?: string
  parent?: string
}

/** The last `bd list` result: the issues, or why there are none. */
export type Snapshot = { issues: BeadsIssue[]; error: string | null }

declare module 'claude-code' {
  interface PluginState {
    mod: { 'mod-beads-tree-snapshot': Snapshot }
  }
}

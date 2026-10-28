import type { BeadsIssue } from '../../types'

/** One drawn line of the tree: the branch glyphs before it and its issue. */
export type TreeRow = { prefix: string; issue: BeadsIssue }

/** Active work first, then by priority (P0 first), then by id. */
const STATUS_ORDER: Record<string, number> = { in_progress: 0, blocked: 1, open: 2, deferred: 3 }
const LOWEST_PRIORITY = 4

const priorityOf = (issue: BeadsIssue): number =>
  Number.isFinite(issue.priority) ? issue.priority : LOWEST_PRIORITY

function compare(a: BeadsIssue, b: BeadsIssue): number {
  return (
    (STATUS_ORDER[a.status] ?? 9) - (STATUS_ORDER[b.status] ?? 9) ||
    priorityOf(a) - priorityOf(b) ||
    a.id.localeCompare(b.id, undefined, { numeric: true })
  )
}

/**
 * Reads `bd list --json` output: the rows that have an id and a title, the
 * first of each id. Throws when the output is not a JSON array.
 */
export function parseIssues(stdout: string): BeadsIssue[] {
  const data: unknown = JSON.parse(stdout)
  if (!Array.isArray(data)) throw new Error('bd list --json did not return a list')

  const seen = new Set<string>()

  return data.filter((row): row is BeadsIssue => {
    const isIssue =
      typeof row === 'object' &&
      row !== null &&
      typeof row.id === 'string' &&
      typeof row.title === 'string' &&
      !seen.has(row.id)
    if (isIssue) seen.add(row.id)

    return isIssue
  })
}

/**
 * Lays the issues out as a tree by `parent`. An issue whose parent is not in
 * the list (closed, or none) is a root.
 */
export function buildTree(issues: readonly BeadsIssue[]): TreeRow[] {
  const ids = new Set(issues.map(issue => issue.id))
  const children = new Map<string, BeadsIssue[]>()
  const roots: BeadsIssue[] = []

  for (const issue of issues) {
    if (issue.parent !== undefined && issue.parent !== issue.id && ids.has(issue.parent)) {
      const siblings = children.get(issue.parent) ?? []
      siblings.push(issue)
      children.set(issue.parent, siblings)
    } else {
      roots.push(issue)
    }
  }

  const rows: TreeRow[] = []
  const seen = new Set<string>()
  const walk = (issue: BeadsIssue, indent: string, branch: string, isLast: boolean) => {
    if (seen.has(issue.id)) return
    seen.add(issue.id)
    rows.push({ prefix: indent + branch, issue })

    const kids = [...(children.get(issue.id) ?? [])].sort(compare)
    const childIndent = branch === '' ? '' : indent + (isLast ? '    ' : '│   ')
    kids.forEach((kid, index) => {
      const isLastKid = index === kids.length - 1
      walk(kid, childIndent, isLastKid ? '└── ' : '├── ', isLastKid)
    })
  }

  for (const root of [...roots].sort(compare)) walk(root, '', '', true)

  // A parent cycle leaves its issues unreached from any root. Start from an
  // issue on the cycle itself (its parent chain revisits it), so issues hanging
  // off the cycle still draw under it.
  for (const issue of [...issues].sort(compare)) {
    if (seen.has(issue.id)) continue
    const chain = new Set<string>()
    let current: BeadsIssue | undefined = issue
    while (current !== undefined && !chain.has(current.id)) {
      chain.add(current.id)
      const parentId: string | undefined = current.parent
      current = issues.find(other => other.id === parentId)
    }
    walk(current ?? issue, '', '', true)
  }

  return rows
}

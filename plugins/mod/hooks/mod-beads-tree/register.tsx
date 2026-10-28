import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Snapshot } from '../../types'
import { buildTree, parseIssues } from './tree'

const PANE = 'mod-beads-tree'
const TITLE = 'Beads'
const REFRESH_MS = 15_000
const BD_TIMEOUT_MS = 10_000
/** A command that runs `bd`: after a separator, a quote, `$(`, a backtick or a path. */
const BD_COMMAND = /(^|[\s;&|()`"'/])bd(\s|$)/

const ICONS: Record<string, string> = {
  open: '○',
  in_progress: '◐',
  blocked: '●',
  deferred: '❄',
  closed: '✓',
}
const COLORS: Record<string, string> = { in_progress: 'warning', blocked: 'error' }

const snapshot = atom({ plugin: 'mod', key: 'mod-beads-tree-snapshot' } as const, {
  issues: [],
  error: null,
})

// Refreshes can overlap (timer, tool calls, the command): only the latest
// one started may store its result.
let latest = 0
// Where the pane was last drawn, for /mod-beads-tree to report. The module's own: a
// reload forgets it until the next draw.
let lastDraw: string | null = null

/** Reads the open issues with `bd list` and stores them for the pane. Never throws. */
async function refresh($: EngineInterface): Promise<void> {
  const run = ++latest
  let next: Snapshot
  try {
    const { exitCode, stdout, stderr } = await $.process.run(
      ['bd', 'list', '--json', '--limit', '0'],
      { timeoutMs: BD_TIMEOUT_MS },
    )
    if (exitCode !== 0) {
      next = { issues: [], error: stderr.trim().split('\n').pop() || `bd exited with ${exitCode}` }
    } else {
      try {
        next = { issues: parseIssues(stdout), error: null }
      } catch (error) {
        next = { issues: [], error: `Could not read bd output: ${String(error)}` }
      }
    }
  } catch {
    next = { issues: [], error: 'bd is not installed or did not answer' }
  }

  try {
    if (run === latest) await update($, snapshot, () => next)
  } catch {
    // The session is ending or the module reloading: nothing left to draw.
  }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'mod-beads-tree',
      description: 'Show or hide the open beads issue tree in a pane',
      argumentHint: '[open|close]',
    })
    void $.ui.open({ id: PANE, title: TITLE }).catch(() => undefined)
    void refresh($)
    $.clock.every(REFRESH_MS, () => void refresh($))

    return next(e)
  })

  on('command.run', { command: 'mod-beads-tree' }, async ($, e) => {
    const action = e.args.trim().toLowerCase()
    if (action !== '' && action !== 'open' && action !== 'close') {
      return { text: `Unknown argument "${e.args.trim()}". Use /mod-beads-tree, /mod-beads-tree open or /mod-beads-tree close.` }
    }

    // With no argument the command toggles. Only a pane the person can see
    // counts as open: one that waits undrawn or behind another tab is shown.
    const current = (await $.ui.panes()).find(open => open.id === PANE)
    const isVisible = current !== undefined && current.isPlaced && current.isShown
    if (action === 'close' || (action === '' && isVisible)) {
      if (current === undefined) return { text: 'Beads pane is already closed.' }
      try {
        await $.ui.close({ id: PANE })
      } catch (error) {
        return { text: `Beads pane could not be closed: ${String(error)}` }
      }

      return { text: 'Beads pane closed.' }
    }

    await refresh($)
    const opened = await $.ui.open({ id: PANE, title: TITLE })
    const { issues, error } = await read($, snapshot)
    const summary = error ?? `${issues.length} not closed`
    if (opened.isPlaced) {
      const pane = (await $.ui.panes()).find(open => open.id === PANE)
      const tab = pane?.isShown === false ? '; behind another pane, pick its tab' : ''
      const drawn = lastDraw === null ? 'not drawn yet' : `last drawn on ${lastDraw}`

      return { text: `Beads pane opened (${summary}; ${drawn}${tab}).` }
    }

    return { text: `Beads pane is open but not drawn: ${opened.reason} (${summary}).` }
  })

  // Redraw right after the agent changes issues, without holding up its result.
  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    const ran = await next(e)
    if (BD_COMMAND.test(e.command)) void refresh($)

    return ran
  }).catch(($, e, next) => next(e)) // replays the command's result; never reruns it

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    lastDraw = `${e.surface}, ${e.props.placement}, ${e.props.bodyColumns} columns`
    const { issues, error } = await read($, snapshot)

    if (error !== null) {
      return <Text color="error">{error}</Text>
    }
    if (issues.length === 0) {
      return <Text dimColor>No open issues.</Text>
    }

    const count = (status: string) => issues.filter(issue => issue.status === status).length

    return (
      <Box flexDirection="column">
        <Text dimColor>
          {issues.length} not closed: {count('in_progress')} in progress, {count('blocked')} blocked
        </Text>
        {buildTree(issues).map(({ prefix, issue }) => (
          <Text key={issue.id} wrap="truncate-end">
            <Text dimColor>{prefix}</Text>
            <Text color={COLORS[issue.status]}>{ICONS[issue.status] ?? '?'}</Text>{' '}
            <Text dimColor>{issue.id}</Text> <Text dimColor>P{issue.priority}</Text>{' '}
            {issue.issue_type === 'epic' ? <Text bold>{issue.title}</Text> : issue.title}
          </Text>
        ))}
      </Box>
    )
  })
}

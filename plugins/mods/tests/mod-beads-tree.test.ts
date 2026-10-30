import type { On } from 'claude-code'
import { expect, mock, test } from 'claude-code/testing'
import type { TestBody } from 'claude-code/testing'

import { buildTree, parseIssues } from '../hooks/mod-beads-tree/tree'

const ISSUES = [
  { id: 'p-a', title: 'Loose task', status: 'open', priority: 3 },
  { id: 'p-e', title: 'Epic', status: 'open', priority: 1, issue_type: 'epic' },
  { id: 'p-e.2', title: 'Second child', status: 'open', priority: 2, parent: 'p-e' },
  { id: 'p-e.1', title: 'First child', status: 'in_progress', priority: 2, parent: 'p-e' },
  { id: 'p-e.1.1', title: 'Grandchild', status: 'open', priority: 3, parent: 'p-e.1' },
  { id: 'p-o', title: 'Orphan of a closed epic', status: 'open', priority: 0, parent: 'p-closed' },
]

const PANE_PROPS = {
  title: 'Beads',
  isFocused: false,
  bodyColumns: 80,
  placement: 'dock' as const,
  scroll: { offset: 0, bodyRows: 30 },
  view: {},
}

/** Answers the engine calls session.start makes, beneath the plugin. */
function stubEngine(on: On) {
  mock.clock(on)
  on('session.start', async (_$, e) => ({ cwd: e.cwd }))
  on('command.register', async (_$, e) => ({ value: { command: e.name } }))
  on('ui.open', async () => ({ value: { isPlaced: true as const } }))
}

const BD_EMPTY = { exitCode: 0, stdout: '[]', stderr: '', isStdoutTruncated: false, isStderrTruncated: false }

/** Runs `/mod-beads-tree` with the given argument, as typed in the composer. */
function runBeads($: Parameters<TestBody>[0], args = '') {
  return $.command.run({
    command: 'mod-beads-tree',
    args,
    origin: { kind: 'composer' },
    presentation: { isFullscreen: false, columns: 80 },
  })
}

test('buildTree nests by parent and sorts active work first', async () => {
  const lines = buildTree(ISSUES).map(row => `${row.prefix}${row.issue.id}`)

  expect(lines).toEqual([
    'p-o',
    'p-e',
    '├── p-e.1',
    '│   └── p-e.1.1',
    '└── p-e.2',
    'p-a',
  ])
})

test('buildTree keeps issues caught in a parent cycle', async () => {
  const rows = buildTree([
    { id: 'x', title: 'x', status: 'open', priority: 2, parent: 'y' },
    { id: 'y', title: 'y', status: 'open', priority: 2, parent: 'x' },
  ])

  expect(rows.map(row => row.issue.id).sort()).toEqual(['x', 'y'])
})

test('buildTree draws issues hanging off a parent cycle under it', async () => {
  const lines = buildTree([
    { id: 'a', title: 'a', status: 'open', priority: 2, parent: 'b' },
    { id: 'b', title: 'b', status: 'open', priority: 2, parent: 'a' },
    { id: 'c', title: 'c', status: 'open', priority: 0, parent: 'a' },
  ]).map(row => `${row.prefix}${row.issue.id}`)

  expect(lines.length).toBe(3)
  expect(lines.filter(line => !line.includes('── '))).toHaveLength(1)
})

test('parseIssues refuses output that is not a list and drops duplicate ids', async () => {
  expect(() => parseIssues('{}')).toThrow()
  const issues = parseIssues(JSON.stringify([ISSUES[0], ISSUES[0], { id: 'no-title' }]))
  expect(issues.map(issue => issue.id)).toEqual(['p-a'])
})

test('buildTree sorts ids numerically and survives a missing priority', async () => {
  const lines = buildTree([
    { id: 'p.10', title: 'ten', status: 'open', priority: 2 },
    { id: 'p.2', title: 'two', status: 'open', priority: 2 },
    { id: 'p.x', title: 'none', status: 'open', priority: undefined as unknown as number },
  ]).map(row => row.issue.id)

  expect(lines).toEqual(['p.2', 'p.10', 'p.x'])
})

test('the pane draws the tree from bd list', async ($, on) => {
  stubEngine(on)
  on('ui.panes', async () => ({ value: [{ id: 'mod-beads-tree', title: 'Beads', isShown: false, isFocused: false, isPlaced: true }] }))
  let argv: readonly string[] = []
  on('process.run', async (_$, e) => {
    argv = e.argv
    return {
      value: {
        exitCode: 0,
        stdout: JSON.stringify(ISSUES),
        stderr: '',
        isStdoutTruncated: false,
        isStderrTruncated: false,
      },
    }
  })
  await $.session.start({ cwd: '/repo', surface: 'terminal', isInteractive: true })

  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({
      plugin: 'mods',
      surface,
      component: 'Pane',
      requestId: 'mod-beads-tree',
      props: PANE_PROPS,
    })

    expect(argv).toEqual(['bd', 'list', '--json', '--brief', '--limit', '0'])
    expect((await ui.find({ text: /6 not closed: 1 in progress, 0 blocked/ }))?.text).toMatch(/6 not closed: 1 in progress, 0 blocked/)
    expect((await ui.find({ text: /│   └── .*p-e\.1\.1/ }))?.text).toMatch(/│   └── .*p-e\.1\.1/)
    await ui.unmount()
  }

  const result = await $.command.run({
    command: 'mod-beads-tree',
    args: '',
    origin: { kind: 'composer' },
    presentation: { isFullscreen: false, columns: 80 },
  })
  expect(result.text).toBe('Beads pane opened (6 not closed; last drawn on desktop, dock, 80 columns; behind another pane, pick its tab).')
})

test('the pane shows why bd failed', async ($, on) => {
  stubEngine(on)
  on('process.run', async () => ({
    value: {
      exitCode: 1,
      stdout: '',
      stderr: 'warning: something\nError: no beads database found\n',
      isStdoutTruncated: false,
      isStderrTruncated: false,
    },
  }))
  await $.session.start({ cwd: '/repo', surface: 'terminal', isInteractive: true })

  const ui = await $.ui.mount({
    plugin: 'mods',
    surface: 'terminal',
    component: 'Pane',
    requestId: 'mod-beads-tree',
    props: PANE_PROPS,
  })

  expect((await ui.find({ text: /no beads database found/ }))?.text).toMatch(/no beads database found/)
  await ui.unmount()
})

test('/mod-beads-tree says why the pane is not drawn', async ($, on) => {
  mock.clock(on)
  on('session.start', async (_$, e) => ({ cwd: e.cwd }))
  on('command.register', async (_$, e) => ({ value: { command: e.name } }))
  on('ui.panes', async () => ({ value: [] }))
  on('ui.open', async () => ({ value: { isPlaced: false as const, reason: 'no attached surface places panes' } }))
  on('process.run', async () => ({
    value: { exitCode: 0, stdout: '[]', stderr: '', isStdoutTruncated: false, isStderrTruncated: false },
  }))
  await $.session.start({ cwd: '/repo', surface: 'terminal', isInteractive: true })

  const result = await $.command.run({
    command: 'mod-beads-tree',
    args: '',
    origin: { kind: 'composer' },
    presentation: { isFullscreen: false, columns: 80 },
  })
  expect(result.text).toMatch(/not drawn: no attached surface places panes \(0 not closed\)/)
})

test('/mod-beads-tree closes a visible pane and opens it again', async ($, on) => {
  stubEngine(on)
  on('process.run', async () => ({ value: BD_EMPTY }))
  let isOpen = true
  const closed: string[] = []
  on('ui.panes', async () => ({
    value: isOpen ? [{ id: 'mod-beads-tree', title: 'Beads', isShown: true, isFocused: false, isPlaced: true }] : [],
  }))
  on('ui.close', async (_$, e) => {
    closed.push(e.id)
    isOpen = false
    return { value: undefined }
  })
  await $.session.start({ cwd: '/repo', surface: 'terminal', isInteractive: true })

  expect((await runBeads($)).text).toBe('Beads pane closed.')
  expect(closed).toEqual(['mod-beads-tree'])

  expect((await runBeads($)).text).toMatch(/^Beads pane opened \(0 not closed/)
  expect(closed).toHaveLength(1)
})

test('/mod-beads-tree open and /mod-beads-tree close do not toggle', async ($, on) => {
  stubEngine(on)
  on('process.run', async () => ({ value: BD_EMPTY }))
  let isOpen = true
  on('ui.panes', async () => ({
    value: isOpen ? [{ id: 'mod-beads-tree', title: 'Beads', isShown: true, isFocused: false, isPlaced: true }] : [],
  }))
  on('ui.close', async () => {
    isOpen = false
    return { value: undefined }
  })
  await $.session.start({ cwd: '/repo', surface: 'terminal', isInteractive: true })

  expect((await runBeads($, 'open')).text).toMatch(/^Beads pane opened/)
  expect(isOpen).toBe(true)
  expect((await runBeads($, ' Close ')).text).toBe('Beads pane closed.')
  expect((await runBeads($, 'close')).text).toBe('Beads pane is already closed.')
  expect((await runBeads($, 'shut')).text).toMatch(/Unknown argument "shut"/)
})

test('the pane says when the bd output was cut short', async ($, on) => {
  stubEngine(on)
  on('process.run', async () => ({
    value: { exitCode: 0, stdout: '[\n  {', stderr: '', isStdoutTruncated: true, isStderrTruncated: false },
  }))
  await $.session.start({ cwd: '/repo', surface: 'terminal', isInteractive: true })

  const ui = await $.ui.mount({
    plugin: 'mods',
    surface: 'terminal',
    component: 'Pane',
    requestId: 'mod-beads-tree',
    props: PANE_PROPS,
  })

  expect((await ui.find({ text: /bd output is too large/ }))?.text).toMatch(/bd output is too large/)
  await ui.unmount()
})

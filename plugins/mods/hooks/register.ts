import type { Register } from 'claude-code'

import { register as modBeadsTree } from './mod-beads-tree/register'

// A plugin has one hooks module, so each mod in this bundle exports its own
// register and this module calls them in turn.
export const register: Register = (on, options) => {
  modBeadsTree(on, options)
}

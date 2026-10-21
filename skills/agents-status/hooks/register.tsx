// Montre à l'utilisateur que les agents de la bibliothèque travaillent :
// - ligne d'état sous la zone de saisie : agents retenus par le régulateur, puis agents en cours ;
// - ligne d'activité animée (« Agent backend au travail… ») tant qu'un sous-agent tourne.
// Chargé automatiquement depuis .claude/skills/agents-status/ ; le régulateur reste seul à décider.
import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register, Timer } from 'claude-code'

import { parseRetained, statusText } from './parse'

const retained = atom({ plugin: 'agents-status', key: 'retained' } as const, [] as string[])
const running = atom({ plugin: 'agents-status', key: 'running' } as const, [] as string[])

const ACTIVE = new Set(['pending', 'running', 'waiting'])

let poll: Timer | undefined

async function show($: EngineInterface) {
  $.ui.status(statusText(await read($, retained), await read($, running)))
}

// Agents lancés par la conversation principale et encore actifs, sans doublon.
async function refresh($: EngineInterface) {
  const agents = await $.agent.list()
  const names = [...new Set(agents.filter(a => !a.parentId && ACTIVE.has(a.status)).map(a => a.type))]
  await update($, running, () => names)
  await show($)
  if (!names.length && poll) {
    poll.cancel()
    poll = undefined
  }
  return names
}

export const register: Register = on => {
  poll = undefined

  on('prompt.submit', async ($, e, next) => {
    // Le mod vit dans .claude/skills/agents-status/ ; le régulateur lit et écrit dans .claude/hooks/.
    // Avant next(e), qui lance le régulateur (hook UserPromptSubmit) : les agents encore au travail,
    // pour qu'un nouveau message ne lance pas un second agent sur le même travail.
    const busy = await refresh($)
    await $.fs.write(`${$.plugin.root}/../../hooks/agents.running`, busy.map(n => `${n}\n`).join('')).catch(() => {})
    const result = await next(e)
    if (result.drop === undefined) {
      const text = await $.fs.read(`${$.plugin.root}/../../hooks/regulator.last`).catch(() => '')
      const names = parseRetained(typeof text === 'string' ? text : '')
      await update($, retained, () => names)
      await show($)
    }
    return result
  }).catch(($, e, next) => next(e))

  on('tool.call', { tool: 'Agent' }, async ($, e, next) => {
    const name = e.subagent_type ?? 'general-purpose'
    await update($, running, list => (list.includes(name) ? list : [...list, name]))
    await show($)

    const result = await next(e)

    // Au premier plan, l'agent a fini ; en arrière-plan, il tourne encore : on suit la liste.
    const names = await refresh($)
    if (names.length && !poll) poll = $.clock.every(1500, () => void refresh($))
    return result
  }).catch(($, e, next) => next(e))

  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    await refresh($)
    return result
  })

  on('ui.render', { component: 'Spinner' }, async ($, e, next) => {
    const names = await read($, running)
    if (!names.length) return next(e)

    const who = names.length === 1 ? `Agent ${names[0]} au travail` : `Agents ${names.join(', ')} au travail`
    return next({ ...e, props: { ...e.props, message: who } })
  })
}

import { describe, expect, mock, test } from 'claude-code/testing'

import { parseRetained, statusText } from '../hooks/parse'


describe('ligne du régulateur', () => {
  test('lit les agents retenus, sans les déclencheurs ni les niveaux', async () => {
    expect(parseRetained('frontend\napi\r\nux-ui\n')).toEqual(['frontend', 'api', 'ux-ui'])
  })

  test('un fichier vide ou illisible ne donne aucun agent', async () => {
    expect(parseRetained('')).toEqual([])
    expect(parseRetained('[Régulateur] texte inattendu\n')).toEqual([])
  })

  test('la ligne d’état montre d’abord les agents au travail', async () => {
    expect(statusText(['api', 'frontend'], ['backend'])).toBe('▶ Agents au travail : backend')
    expect(statusText(['api', 'frontend'], [])).toBe('◆ Agents retenus : api, frontend')
    expect(statusText([], [])).toBeUndefined()
  })
})

describe('agents au travail pour le régulateur', () => {
  test('les écrit avant que le régulateur lise le nouveau message', async ($, on) => {
    const order: string[] = []
    let written: { path: string; text: string } | undefined
    on('fs.write', ($, e) => {
      written = e
      order.push('écriture')
      return { value: undefined } as never
    })
    on('fs.read', () => ({ value: '' }) as never)
    on('agent.list', () => ({ value: [
      { id: 'a1', type: 'frontend', status: 'running', description: 'lecteur PDF' },
      { id: 'a2', type: 'backend', status: 'completed', description: 'lot terminé' },
    ] }) as never)
    // Sous le mod, à la place de l'engine : là où tournent les hooks UserPromptSubmit (le régulateur).
    on('prompt.submit', () => {
      order.push('régulateur')
      return {} as never
    })
    await $.prompt.submit({ text: 'ajoute un bouton', asUser: true })
    expect(order).toEqual(['écriture', 'régulateur'])
    expect(written?.path).toMatch(/hooks\/agents\.running$/)
    expect(written?.text).toBe('frontend\n')
  })
})

describe('ligne d’activité', () => {
  test('nomme les agents au travail sur chaque surface', async ($, on) => {
    mock.clock(on)
    // Dessin de base de la ligne d'activité : le message s'il y en a un, sinon le mot.
    on('ui.render', { component: 'Spinner' }, ($, e) => {
      const { Text } = $.ui.resolve(e)
      return <Text>{e.props.message ?? e.props.word}</Text>
    })
    let status: string | undefined
    on('ui.status', ($, e) => {
      status = e.text
      return { value: undefined } as never
    })
    on('tool.call', { tool: 'Agent' }, () => ({ result: { status: 'async_launched' } }) as never)
    on('agent.list', () => ({ value: [
      { id: 'a1', type: 'backend', status: 'running', description: 'endpoint' },
      { id: 'a2', type: 'database', status: 'running', description: 'migration' },
    ] }) as never)
    await $.tool.call({ tool: 'Agent', subagent_type: 'backend', description: 'endpoint', prompt: 'x' } as never)
    expect(status).toBe('▶ Agents au travail : backend, database')
    for (const surface of ['terminal', 'desktop', 'vscode'] as const) {
      const ui = await $.ui.mount({
        plugin: 'agents-status',
        surface,
        component: 'Spinner',
        props: { word: 'Working', message: null, suffix: '…', mode: 'tool-use' },
      })
      expect(await ui.find({ text: /Agents backend, database au travail/ })).toBeDefined()
      await ui.unmount()
    }
  })
})

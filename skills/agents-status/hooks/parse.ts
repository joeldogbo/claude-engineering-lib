// Lit .claude/hooks/regulator.last, que le régulateur (.claude/hooks/regulator) réécrit à chaque
// prompt : un nom d'agent retenu par ligne, fichier vide quand aucun agent n'est retenu.
export const parseRetained = (text: string): string[] =>
  text
    .split(/\r?\n/)
    .map(line => line.trim())
    .filter(line => /^[a-z0-9-]+$/.test(line))

// Texte de la ligne d'état : les agents au travail d'abord, puis ceux que le régulateur a retenus.
export const statusText = (retained: readonly string[], running: readonly string[]): string | undefined => {
  if (running.length) return `▶ Agents au travail : ${running.join(', ')}`
  if (retained.length) return `◆ Agents retenus : ${retained.join(', ')}`
  return undefined
}

declare module 'claude-code' {
  interface PluginState {
    'agents-status': { retained: string[]; running: string[] }
  }
}

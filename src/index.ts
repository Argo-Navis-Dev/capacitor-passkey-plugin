import { registerPlugin } from '@capacitor/core';

import type { PasskeyPlugin as PasskeyPluginType } from './definitions';

// Rename the type locally to avoid conflict
const PasskeyPlugin = registerPlugin<PasskeyPluginType>('PasskeyPlugin', {
  web: () => import('./web').then((m) => new m.WebPasskeyPlugin()),
});

export * from './definitions';
export { PasskeyPlugin };

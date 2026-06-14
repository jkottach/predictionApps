export type TenantId = 'fcc' | 'mandrake';

const tenants = {
  fcc: {
    id: 'fcc' as const,
    name: 'FCC Worldcup 26',
    badge: 'Official FCC prediction league',
    loginTitle: 'Sign in to FCC Worldcup 26',
    registerTitle: 'Join FCC Worldcup 26',
    description: 'Predict World Cup scores, earn points, and win prizes with FCC Worldcup 26',
  },
  mandrake: {
    id: 'mandrake' as const,
    name: 'Mandrake Worldcup 26',
    badge: 'Official prediction league',
    loginTitle: 'Sign in',
    registerTitle: 'Join Mandrake Worldcup 26',
    description: 'Predict World Cup scores, earn points, and win prizes with Mandrake Worldcup 26',
  },
} as const;

const tenantId = (import.meta.env.VITE_TENANT ?? 'fcc') as TenantId;
const known = tenantId in tenants ? tenantId : 'fcc';

export const tenant = tenants[known];

/** Static file trong public/ — tu dong them base path (/ hoac /hrm/). */
export function publicAsset(path: string): string {
  const base = import.meta.env.BASE_URL || '/';
  const file = path.replace(/^\//, '');
  return `${base}${file}`;
}

export const LOGO_SRC = publicAsset('logo.png');

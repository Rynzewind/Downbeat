export type DeviceAuthenticator = (authorization: string | null) => string | null | Promise<string | null>;

export async function requireDevice(request: Request, authenticate: DeviceAuthenticator): Promise<string | null> {
  const value = request.headers.get('authorization');
  if (!value?.startsWith('Bearer ')) return null;
  return authenticate(value.slice(7));
}

// hello OS v2.0 — Device Linking Protocol (Sesame Multi-Device)
// QR-based device linking: primary device generates request, new device scans.
// The linking secret is used as a pre-shared key for encrypted history transfer.

export interface LinkingRequest {
  userId: string;
  linkingSecret: string; // 32-byte random, base64
  serverUrl: string;
  primaryDeviceId: number;
}

export function encodeLinkingRequest(req: LinkingRequest): string {
  return JSON.stringify({
    u: req.userId,
    s: req.linkingSecret,
    url: req.serverUrl,
    pd: req.primaryDeviceId,
  });
}

export function decodeLinkingRequest(payload: string): LinkingRequest {
  const json = JSON.parse(payload);
  return {
    userId: json.u,
    linkingSecret: json.s,
    serverUrl: json.url,
    primaryDeviceId: json.pd,
  };
}

export type LinkingState =
  | 'idle'
  | 'waitingForScan'
  | 'verifying'
  | 'transferringHistory'
  | 'complete'
  | 'failed';

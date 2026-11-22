import {
    SOURCE_SYNC_CAPABILITY,
    type SourceServerConnection,
    type ServerInstanceInfo,
} from '@iptvnator/shared/interfaces';

export const CONNECTION_KEY = 'iptvnator:source-server';
export const DISABLED_KEY = 'iptvnator:source-server-disabled';
const INCOMPATIBLE = 'SOURCE_SYNC.INCOMPATIBLE';
const OFFLINE = 'SOURCE_SYNC.OFFLINE';
let selected: SourceServerConnection | null = null;
let readFailed = false;
let verificationEpoch = 0;

export const sourceConnection = (): SourceServerConnection | null => null;
export const sourceConnectionReadFailed = (): boolean => false;
export function markSourceConnectionReadFailed(): void {
    readFailed = false;
}
export const sourceVerificationEpoch = () => verificationEpoch;
export const sourceProfileName = () => 'iptvnator';
export const tokenKey = ({ apiUrl, instanceId }: SourceServerConnection) =>
    `iptvnator:server-token:${JSON.stringify([apiUrl, instanceId])}`;

export function parseSourceConnection(raw: string): SourceServerConnection {
    const connection = JSON.parse(raw) as SourceServerConnection;
    if (
        typeof connection?.apiUrl !== 'string' ||
        typeof connection.instanceId !== 'string' ||
        !connection.instanceId
    )
        throw new Error(INCOMPATIBLE);
    const apiUrl = new URL(connection.apiUrl);
    if (
        !['http:', 'https:'].includes(apiUrl.protocol) ||
        apiUrl.username ||
        apiUrl.password ||
        apiUrl.search ||
        apiUrl.hash
    )
        throw new Error(INCOMPATIBLE);
    return {
        apiUrl: apiUrl.toString().replace(/\/$/, ''),
        instanceId: connection.instanceId,
    };
}

export function assertSourceInstance(
    value: unknown
): asserts value is ServerInstanceInfo & { instanceId: string } {
    const info = value as ServerInstanceInfo;
    if (
        info?.service !== 'iptvnator' ||
        info.apiVersion !== 1 ||
        info.storage !== 'server' ||
        typeof info.instanceId !== 'string' ||
        !info.instanceId ||
        !Array.isArray(info.capabilities) ||
        !info.capabilities.includes(SOURCE_SYNC_CAPABILITY)
    ) {
        throw new Error(INCOMPATIBLE);
    }
}

/** Runs before Angular constructs storage or reads the source inventory. */
export async function prepareSourceConnection(
    runtimeBackendUrl?: string
): Promise<void> {
    selected = null;
    invalidateSourceVerification();
    readFailed = false;
    try {
        localStorage.removeItem(CONNECTION_KEY);
    } catch {
        // ignore
    }
    return;
}

export function invalidateSourceVerification(): void {
    verificationEpoch++;
}

export function isSourceBackendRequest(url: string): boolean {
    if (!selected || window.electron?.sourceSyncConnection) return false;
    const target = new URL(url, location.href);
    const backend = new URL(selected.apiUrl);
    return (
        target.origin === backend.origin &&
        target.pathname.startsWith(`${backend.pathname.replace(/\/+$/, '')}/`)
    );
}

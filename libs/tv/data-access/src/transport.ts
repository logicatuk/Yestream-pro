import { httpUrl, Source } from '@iptvnator/tv/util';
export class ProviderRequestError extends Error {
    constructor(
        readonly status: number,
        readonly upstream = false,
        readonly missingTarget = false
    ) {
        super('Provider request failed. Check the source and backend.');
    }
}
function parseSimpleM3u(content: string): { playlist: { items: any[] } } {
    const items: any[] = [];
    const lines = content.split(/\r?\n/);
    let currentInf: { name?: string; group?: { title?: string }; tvg?: { logo?: string } } | null = null;
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (line.startsWith('#EXTINF:')) {
            const logoMatch = line.match(/tvg-logo="([^"]*)"/i);
            const groupMatch = line.match(/group-title="([^"]*)"/i);
            const commaIdx = line.indexOf(',');
            const name = commaIdx !== -1 ? line.slice(commaIdx + 1).trim() : 'Channel';
            currentInf = {
                name,
                group: { title: groupMatch ? groupMatch[1] : 'General' },
                tvg: { logo: logoMatch ? logoMatch[1] : undefined },
            };
        } else if (line && !line.startsWith('#')) {
            if (currentInf) {
                items.push({
                    url: line,
                    name: currentInf.name,
                    group: currentInf.group,
                    tvg: currentInf.tvg,
                });
                currentInf = null;
            }
        }
    }
    return { playlist: { items } };
}

export class ProviderTransport {
    private targets = new Map<string, string>();
    constructor(
        readonly backend: string,
        private readonly accessToken = ''
    ) {
        if (backend) {
            try {
                httpUrl(backend);
            } catch {
                // Ignore invalid or empty backend URL
            }
        }
    }
    private async json(
        url: string,
        signal: AbortSignal,
        init?: RequestInit
    ): Promise<unknown> {
        const controller = new AbortController();
        const cancel = () => controller.abort();
        signal.addEventListener('abort', cancel);
        if (signal.aborted) cancel();
        const timer = setTimeout(cancel, 35000);
        try {
            const response = await fetch(url, {
                ...init,
                signal: controller.signal,
                redirect: 'error',
                headers: {
                    ...(this.accessToken
                        ? { Authorization: `Bearer ${this.accessToken}` }
                        : {}),
                    ...init?.headers,
                },
            });
            if (!response.ok) {
                const body =
                    response.status === 404
                        ? await response.json().catch(() => null)
                        : null;
                throw new ProviderRequestError(
                    response.status,
                    false,
                    body?.message === 'Provider target not found'
                );
            }
            const value = await response.json();
            if (
                value?.type === 'ERROR' ||
                value?.status >= 400 ||
                (value?.message && !('payload' in value))
            )
                throw new ProviderRequestError(
                    Number(value?.status) || 502,
                    true
                );
            return value;
        } finally {
            clearTimeout(timer);
            signal.removeEventListener('abort', cancel);
        }
    }
    private async target(url: string, signal: AbortSignal) {
        const cached = this.targets.get(url);
        if (cached) return cached;
        const promise = this.json(
            `${this.backend.replace(/\/$/, '')}/provider-targets`,
            signal,
            {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ url: httpUrl(url) }),
            }
        ).then((v) => (v as { targetId: string }).targetId);
        const id = await promise;
        this.targets.set(url, id);
        return id;
    }
    private async directRequest(
        source: Source,
        route: 'xtream' | 'stalker' | 'parse',
        params: Record<string, string | number>,
        signal: AbortSignal,
        endpoint = source.endpoint ?? source.url
    ): Promise<unknown> {
        if (route === 'xtream') {
            let base = (endpoint || '').trim();
            if (!/^https?:\/\//i.test(base)) {
                base = `http://${base}`;
            }
            base = base.replace(/\/+(?:player_api|get|panel_api)\.php.*$/i, '').replace(/\/+$/, '');
            const url = new URL(`${base}/player_api.php`);
            Object.keys(params).forEach((k) => url.searchParams.set(k, String(params[k])));
            const res = await fetch(url.href, { signal });
            if (!res.ok) {
                throw new ProviderRequestError(res.status, true);
            }
            const json = await res.json();
            return json?.payload !== undefined ? json.payload : json;
        }
        if (route === 'parse') {
            const res = await fetch(endpoint, { signal });
            if (!res.ok) {
                throw new ProviderRequestError(res.status, true);
            }
            const text = await res.text();
            return parseSimpleM3u(text);
        }
        throw new ProviderRequestError(500, true);
    }

    async request(
        source: Source,
        route: 'xtream' | 'stalker' | 'parse',
        params: Record<string, string | number>,
        signal: AbortSignal,
        endpoint = source.endpoint ?? source.url,
        repaired = false
    ): Promise<unknown> {
        if (!this.backend) {
            return this.directRequest(source, route, params, signal, endpoint);
        }
        try {
            const targetId = await this.target(endpoint, signal);
            if (signal.aborted) throw new DOMException('Aborted', 'AbortError');
            const query = new URLSearchParams({ targetId });
            if (route === 'parse' && source.userAgent)
                query.set('userAgent', source.userAgent);
            Object.keys(params).forEach((k) => query.set(k, String(params[k])));
            let result: { payload?: unknown };
            try {
                result = (await this.json(
                    `${this.backend.replace(/\/$/, '')}/${route}?${query}`,
                    signal
                )) as { payload?: unknown };
            } catch (error) {
                if (
                    !repaired &&
                    !signal.aborted &&
                    error instanceof ProviderRequestError &&
                    error.missingTarget
                ) {
                    this.targets.delete(endpoint);
                    return this.request(
                        source,
                        route,
                        params,
                        signal,
                        endpoint,
                        true
                    );
                }
                throw error;
            }
            return route === 'parse' ? result : (result?.payload !== undefined ? result.payload : result);
        } catch (error) {
            // If backend is unreachable or dead (fetch failed), seamlessly fallback to direct provider fetch
            if (!signal.aborted && (route === 'xtream' || route === 'parse')) {
                if (!(error instanceof ProviderRequestError)) {
                    return this.directRequest(source, route, params, signal, endpoint);
                }
            }
            throw error;
        }
    }
    clear() {
        this.targets.clear();
    }
}

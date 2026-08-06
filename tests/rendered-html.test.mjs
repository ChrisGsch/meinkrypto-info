import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const developmentPreviewMeta =
  /<meta(?=[^>]*\bname=["']codex-preview["'])(?=[^>]*\bcontent=["']development["'])[^>]*>/i;

test("renders development preview metadata", async () => {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  const response = await worker.fetch(
    new Request("http://localhost/", {
      headers: { accept: "text/html" },
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );

  assert.equal(response.status, 200);
  assert.match(
    response.headers.get("content-type") ?? "",
    /^text\/html\b/i,
  );
  const html = await response.text();
  assert.match(html, developmentPreviewMeta);
  assert.match(html, /Über mich/);
  assert.match(html, /assets\/christoph-gschnaidtner\.jpg/);
  assert.match(html, /meinKrypto@christoph-gschnaidtner\.de/);
  assert.doesNotMatch(html, /tel:/i);

  const componentSource = await readFile(
    new URL("../components/CryptoSite.tsx", import.meta.url),
    "utf8",
  );
  assert.match(componentSource, /Am Steinberg 40/);
  assert.match(componentSource, /82237 Wörthsee/);
  assert.doesNotMatch(componentSource, /tel:/i);
  assert.doesNotMatch(componentSource, /mail@christoph-gschnaidtner\.de/i);
  assert.doesNotMatch(
    componentSource,
    /href=["']https:\/\/www\.christoph-gschnaidtner\.de/i,
  );
  assert.match(componentSource, /data\/update-status\.json/);
  assert.match(componentSource, /data-status-warning/);
});

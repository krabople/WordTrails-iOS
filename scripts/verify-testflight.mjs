#!/usr/bin/env node
import { writeFile } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';
import { createAppleClient } from './apple-setup.mjs';

export function readBuildSnapshot(response, { appId, buildNumber, marketingVersion }) {
  if (!Array.isArray(response.data)) throw new Error('Apple returned an invalid builds list.');
  const included = response.included || [];
  const matches = response.data.filter((build) => {
    const version = included.find((item) => item.type === 'preReleaseVersions' && item.id === build.relationships?.preReleaseVersion?.data?.id);
    return build.attributes?.version === buildNumber && build.relationships?.app?.data?.id === appId
      && version?.attributes?.version === marketingVersion && version?.attributes?.platform === 'IOS';
  });
  if (matches.length > 1) throw new Error('More than one exact iOS build was returned.');
  if (!matches.length) return { appId, buildNumber, marketingVersion, processingState: 'NOT_YET_VISIBLE', processingVerified: false };
  const build = matches[0];
  const beta = included.find((item) => item.type === 'buildBetaDetails' && item.id === build.relationships?.buildBetaDetail?.data?.id);
  return { appId, buildId: build.id, buildNumber, marketingVersion, processingState: build.attributes.processingState,
    processingVerified: build.attributes.processingState === 'VALID' && !build.attributes.expired,
    expired: !!build.attributes.expired, uploadedDate: build.attributes.uploadedDate || null,
    internalBuildState: beta?.attributes?.internalBuildState || null, externalBuildState: beta?.attributes?.externalBuildState || null };
}

export async function verifyProcessedBuild({ api, appId, buildNumber, marketingVersion, timeoutMs = 15 * 60_000, pollMs = 30_000, now = Date.now, sleep = delay, onObservation = async () => {} }) {
  if (!appId || !buildNumber || !marketingVersion) throw new Error('App ID, build number and marketing version are required.');
  if (!(timeoutMs > 0) || !(pollMs > 0)) throw new Error('Polling durations must be positive.');
  const deadline = now() + timeoutMs;
  const query = new URLSearchParams({ 'filter[app]': appId, 'filter[version]': buildNumber,
    'filter[preReleaseVersion.version]': marketingVersion, 'filter[preReleaseVersion.platform]': 'IOS',
    include: 'app,preReleaseVersion,buildBetaDetail', limit: '10' });
  for (;;) {
    const snapshot = { ...readBuildSnapshot(await api.request(`/v1/builds?${query}`), { appId, buildNumber, marketingVersion }), checkedAt: new Date(now()).toISOString() };
    await onObservation(snapshot);
    if (snapshot.expired) throw new Error('The matching TestFlight build is expired.');
    if (snapshot.processingVerified) return snapshot;
    if (['FAILED', 'INVALID'].includes(snapshot.processingState)) throw new Error(`Apple processing ended with ${snapshot.processingState}.`);
    if (now() >= deadline) throw new Error(`Timed out waiting for Apple processing; latest state: ${snapshot.processingState}.`);
    await sleep(Math.min(pollMs, Math.max(1, deadline - now())));
  }
}

async function main() {
  const required = (name) => { const value = process.env[name]?.trim(); if (!value) throw new Error(`Missing ${name}.`); return value; };
  const index = process.argv.indexOf('--output'), output = index >= 0 ? process.argv[index + 1] : null;
  if (index >= 0 && !output) throw new Error('--output requires a path.');
  const api = createAppleClient({ issuerId: required('APPSTORE_ISSUER_ID'), keyId: required('APPSTORE_KEY_ID'), privateKey: required('APPSTORE_PRIVATE_KEY') });
  const result = await verifyProcessedBuild({ api, appId: required('APPSTORE_APP_ID'), buildNumber: required('BUILD_NUMBER'), marketingVersion: required('MARKETING_VERSION'),
    onObservation: async (snapshot) => {
      console.log(`Build ${snapshot.marketingVersion} (${snapshot.buildNumber}): ${snapshot.processingState}`);
      if (output) await writeFile(output, `${JSON.stringify(snapshot, null, 2)}\n`, { mode: 0o600 });
    } });
  console.log(JSON.stringify(result, null, 2));
  console.log('Apple processing verified. Tester assignment and external beta approval are separate.');
}
if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main().catch((error) => { console.error(error.message); process.exitCode = 1; });
}

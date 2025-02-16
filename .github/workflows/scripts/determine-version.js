#!/usr/bin/env node

const fs = require('fs');
const { execSync } = require('child_process');

function getGccVersion() {
    const content = fs.readFileSync('versions.sh', 'utf8');
    const match = content.match(/^export GCC_VERSION=(.+)/m);
    if (!match) throw new Error('Could not find GCC_VERSION in versions.sh');
    return match[1];
}

function getGitHash() {
    return execSync('git rev-parse --short HEAD', { encoding: 'utf8' }).trim();
}

function getTagsAtHead() {
    const result = execSync('git tag --points-at HEAD', { encoding: 'utf8' });
    return result.trim().split('\n').filter(Boolean);
}

function getCommitDate(gitHash) {
    const env = { ...process.env, TZ: 'UTC' };
    return execSync(
        `git log -1 --format=%cd --date=format-local:'%Y%m%d-%H%M' ${gitHash}`,
        { encoding: 'utf8', env }
    ).trim();
}

// Look for version tag
const tags = getTagsAtHead();
const versionTag = tags.find(tag => /^v\d+\.\d+\.\d+[_]*/.test(tag));

if (versionTag) {
    // Use tag as version (strip leading 'v')
    console.log(versionTag.slice(1));
} else {
    // Fall back to timestamp-based version
    const gccVersion = getGccVersion();
    const gitHash = getGitHash();
    const datetime = getCommitDate(gitHash);
    console.log(`${gccVersion}_${datetime}-${gitHash}`);
}
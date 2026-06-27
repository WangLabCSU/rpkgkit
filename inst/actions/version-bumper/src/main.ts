import * as core from '@actions/core';
import { exec } from '@actions/exec';

/**
 * Parse version string into components
 */
function parseVersion(version: string): { major: number; minor: number; patch: number } {
    const parts = version.split('.').map(Number);

    if (parts.length !== 3 || parts.some(isNaN)) {
        throw new Error(`Invalid version format: ${version}. Expected: X.Y.Z`);
    }

    return {
        major: parts[0],
        minor: parts[1],
        patch: parts[2]
    };
}

/**
 * Calculate new version based on bump type
 */
function bumpVersion(
    currentVersion: string,
    type: string,
    customVersion?: string
): string {
    if (type === 'custom') {
        if (!customVersion || customVersion.trim() === '') {
            throw new Error('custom_version is required when type=custom');
        }

        if (!/^\d+\.\d+\.\d+$/.test(customVersion)) {
            throw new Error(`Invalid custom version: ${customVersion}. Expected: X.Y.Z`);
        }

        return customVersion;
    }

    const ver = parseVersion(currentVersion);

    switch (type) {
        case 'major':
            return `${ver.major + 1}.0.0`;
        case 'minor':
            return `${ver.major}.${ver.minor + 1}.0`;
        case 'patch':
            return `${ver.major}.${ver.minor}.${ver.patch + 1}`;
        default:
            throw new Error(`Invalid bump type: "${type}". Use: major, minor, patch, custom`);
    }
}

/**
 * Get current version from DESCRIPTION using R
 */
async function getCurrentVersion(): Promise<string> {
    let output = '';
    let errorOutput = '';

    try {
        await exec('Rscript', [
            '-e',
            'cat(as.character(desc::desc_get_version()))'
        ], {
            listeners: {
                stdout: (data: Buffer) => {
                    output += data.toString();
                },
                stderr: (data: Buffer) => {
                    errorOutput += data.toString();
                }
            }
        });
    } catch (error) {
        if (errorOutput) {
            core.error(`R error: ${errorOutput}`);
        }
        throw new Error('Failed to get version. Is desc package installed?');
    }

    const version = output.trim();
    if (!version) {
        throw new Error('Empty version from DESCRIPTION');
    }

    return version;
}

/**
 * Set new version in DESCRIPTION using R
 */
async function setVersion(newVersion: string): Promise<void> {
    let errorOutput = '';

    try {
        await exec('Rscript', [
            '-e',
            `desc::desc_set_version('${newVersion}')`
        ], {
            listeners: {
                stderr: (data: Buffer) => {
                    errorOutput += data.toString();
                }
            }
        });
    } catch (error) {
        if (errorOutput) {
            core.error(`R error: ${errorOutput}`);
        }
        throw new Error(`Failed to set version to ${newVersion}`);
    }

    core.info(`✅ Updated DESCRIPTION to v${newVersion}`);
}

/**
 * Infer bump type from last commit message
 */
async function inferBumpTypeFromCommit(): Promise<string> {
    let output = '';

    await exec('git', ['log', '-1', '--pretty=%B'], {
        listeners: {
            stdout: (data: Buffer) => {
                output += data.toString();
            }
        }
    });

    const msg = output.toLowerCase();

    if (/\b(major|breaking)\!?/.test(msg)) {
        core.info('🔍 Detected major/breaking change');
        return 'major';
    }

    if (/\b(feat|feature|minor)\!?/.test(msg)) {
        core.info('🔍 Detected feature/minor change');
        return 'minor';
    }

    if (/\b(fix|patch|bug)\!?/.test(msg)) {
        core.info('🔍 Detected fix/patch');
        return 'patch';
    }

    core.info('🔍 No bump keywords in commit message');
    return 'none';
}

/**
 * Update version badges in README files
 */
async function updateReadmeBadges(newVersion: string): Promise<void> {
    const files = ['README.md', 'README.Rmd'];

    for (const file of files) {
        try {
            const fs = require('fs');
            if (!fs.existsSync(file)) {
                continue;
            }

            await exec('sed', [
                '-i',
                `s|\\(badge/devel%20version-\\)[0-9]\\+\\.[0-9]\\+\\.[0-9]\\+|\\1${newVersion}|g`,
                file
            ]);

            core.info(`✅ Updated badge in ${file}`);
        } catch (error) {
            core.warning(`Could not update ${file}: ${error}`);
        }
    }
}

/**
 * Main execution
 */
async function run(): Promise<void> {
    try {
        // 1. Get inputs
        const customVersion = core.getInput('custom_version');
        let bumpType = core.getInput('version_type') || 'patch';

        core.startGroup('📦 Input Parameters');
        core.info(`version_type: ${bumpType}`);
        core.info(`custom_version: ${customVersion || '(not set)'}`);
        core.endGroup();

        // 2. Infer from commit if needed
        if (!customVersion && bumpType === 'patch') {
            const inferred = await inferBumpTypeFromCommit();
            if (inferred !== 'none') {
                bumpType = inferred;
                core.info(`🔄 Using inferred type: ${bumpType}`);
            }
        }

        // 3. Get current version
        const currentVersion = await getCurrentVersion();
        core.setOutput('old_version', currentVersion);
        core.info(`📌 Current: v${currentVersion}`);

        // 4. Check if bump needed
        if (bumpType === 'none' && !customVersion) {
            core.info('⏭️  No bump needed');
            core.setOutput('bumped', 'false');
            core.setOutput('new_version', currentVersion);
            return;
        }

        // 5. Calculate new version
        const newVersion = bumpVersion(currentVersion, bumpType, customVersion);
        core.info(`🆕 New: v${newVersion}`);

        // 6. Validate
        if (!/^\d+\.\d+\.\d+$/.test(newVersion)) {
            throw new Error(`Invalid version: ${newVersion}`);
        }

        // 7. Update DESCRIPTION
        await setVersion(newVersion);

        // 8. Set outputs
        core.setOutput('new_version', newVersion);
        core.setOutput('bumped', 'true');

        core.info(`🎉 Success: ${currentVersion} → ${newVersion}`);

    } catch (error) {
        if (error instanceof Error) {
            core.setFailed(`❌ Failed: ${error.message}`);
        } else {
            core.setFailed('❌ Unknown error');
        }
    }
}

run();
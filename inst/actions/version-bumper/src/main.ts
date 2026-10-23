import * as core from '@actions/core';
import { exec } from '@actions/exec';
import * as fs from 'fs';

/** Path of the NEWS file used as the release gate */
const NEWS_FILE = 'NEWS.md';

/** Path of the Rust crate manifest kept in sync with the R package version */
const CARGO_FILE = 'src/rust/Cargo.toml';

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
 * Compare two X.Y.Z version strings
 * Returns a positive number if `a` is greater than `b`, a negative number if
 * `a` is lower than `b`, and 0 when both versions are equal.
 */
function compareVersions(a: string, b: string): number {
    const verA = parseVersion(a);
    const verB = parseVersion(b);

    const keys: Array<'major' | 'minor' | 'patch'> = ['major', 'minor', 'patch'];
    for (const key of keys) {
        if (verA[key] !== verB[key]) {
            return verA[key] - verB[key];
        }
    }

    return 0;
}

/**
 * Get the highest version documented in NEWS.md
 *
 * Reads the markdown headings of NEWS.md (e.g. `# pkg 1.2.3 (2026-01-01)`)
 * and returns the greatest X.Y.Z version found. Returns `null` when the file
 * is missing or holds no version heading.
 */
function getMaxNewsVersion(): string | null {
    if (!fs.existsSync(NEWS_FILE)) {
        return null;
    }

    const headings = fs
        .readFileSync(NEWS_FILE, 'utf8')
        .split(/\r?\n/)
        .filter((line: string) => /^#{1,6}\s+\S/.test(line));

    const versions: string[] = [];
    for (const heading of headings) {
        const match = heading.match(/\b(\d+\.\d+\.\d+)\b/);
        if (match) {
            versions.push(match[1]);
        }
    }

    if (versions.length === 0) {
        return null;
    }

    return versions.reduce((max, version) =>
        compareVersions(version, max) > 0 ? version : max
    );
}

/** Matches a literal `version = "x.y.z"` line, capturing indent, quotes and trailing text */
const CARGO_VERSION_LINE = /^(\s*version\s*=\s*)(["'])([^"']+)\2(.*)$/;

/** Matches a TOML table header such as `[package]` */
const TOML_SECTION_LINE = /^\s*\[([^\]]+)\]\s*(?:#.*)?$/;

/**
 * Locate the `version` key of the `[package]` table
 *
 * Only the `[package]` table is inspected, so `version` keys of dependencies
 * (e.g. `[dependencies.serde] version = "1"`) are never touched.
 * Returns `null` when the table holds no literal version (for instance when it
 * inherits `version.workspace = true`).
 */
function findCargoPackageVersion(
    lines: string[]
): { version: string; lineIndex: number } | null {
    let inPackage = false;

    for (let i = 0; i < lines.length; i++) {
        const section = lines[i].match(TOML_SECTION_LINE);
        if (section) {
            inPackage = section[1].trim() === 'package';
            continue;
        }

        if (!inPackage) {
            continue;
        }

        const match = lines[i].match(CARGO_VERSION_LINE);
        if (match) {
            return { version: match[3], lineIndex: i };
        }
    }

    return null;
}

/**
 * Get the crate version declared in the `[package]` table of
 * `src/rust/Cargo.toml`
 *
 * Returns `null` when the manifest is missing or declares no literal version.
 */
function getCargoVersion(): string | null {
    if (!fs.existsSync(CARGO_FILE)) {
        return null;
    }

    const lines = fs.readFileSync(CARGO_FILE, 'utf8').split(/\r?\n/);
    const found = findCargoPackageVersion(lines);

    return found === null ? null : found.version;
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
 * Sync the Rust crate version in `src/rust/Cargo.toml`
 *
 * Only the `version` key of the `[package]` table is rewritten; the rest of the
 * manifest (formatting, comments, dependencies) is preserved byte for byte.
 * The same NEWS.md release gate as DESCRIPTION applies: a version higher than
 * the highest one documented in NEWS.md is never written.
 */
function updateCargoVersion(
    newVersion: string,
    maxNewsVersion: string | null
): void {
    if (!fs.existsSync(CARGO_FILE)) {
        core.info(`⏭️  ${CARGO_FILE} not found, skipping Rust crate version`);
        return;
    }

    if (
        maxNewsVersion !== null &&
        compareVersions(newVersion, maxNewsVersion) > 0
    ) {
        core.warning(
            `⏭️  Skipping ${CARGO_FILE}: v${newVersion} is higher than the ` +
            `highest version in ${NEWS_FILE} (v${maxNewsVersion}).`
        );
        return;
    }

    const content = fs.readFileSync(CARGO_FILE, 'utf8');
    const lines = content.split(/\r?\n/);
    const found = findCargoPackageVersion(lines);

    if (found === null) {
        core.warning(
            `⏭️  No literal version in the [package] table of ${CARGO_FILE}`
        );
        return;
    }

    if (found.version === newVersion) {
        core.info(`✅ ${CARGO_FILE} already at v${newVersion}`);
        return;
    }

    const match = lines[found.lineIndex].match(CARGO_VERSION_LINE);
    if (match === null) {
        core.warning(`⏭️  Could not rewrite the version line of ${CARGO_FILE}`);
        return;
    }

    lines[found.lineIndex] =
        `${match[1]}${match[2]}${newVersion}${match[2]}${match[4]}`;

    fs.writeFileSync(CARGO_FILE, lines.join(content.includes('\r\n') ? '\r\n' : '\n'));

    core.info(
        `✅ Updated ${CARGO_FILE} to v${newVersion} (was v${found.version})`
    );
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
            } else {
                bumpType = 'none';
                core.info('⏭️  No bump keywords in commit message, skipping');
            }
        }

        // 3. Get current version
        const currentVersion = await getCurrentVersion();
        core.setOutput('old_version', currentVersion);
        core.info(`📌 Current: v${currentVersion}`);

        // 4. Get current Rust crate version (optional)
        const cargoVersion = getCargoVersion();
        if (cargoVersion !== null) {
            core.info(`📌 Current Rust crate (${CARGO_FILE}): v${cargoVersion}`);
        }

        // 5. Check if bump needed
        if (bumpType === 'none' && !customVersion) {
            core.info('⏭️  No bump needed');
            core.setOutput('bumped', 'false');
            core.setOutput('new_version', currentVersion);
            return;
        }

        // 6. Calculate new version
        const newVersion = bumpVersion(currentVersion, bumpType, customVersion);
        core.info(`🆕 New: v${newVersion}`);

        // 7. Validate
        if (!/^\d+\.\d+\.\d+$/.test(newVersion)) {
            throw new Error(`Invalid version: ${newVersion}`);
        }

        // 8. Release gate: never go beyond what NEWS.md documents
        const maxNewsVersion = getMaxNewsVersion();
        if (maxNewsVersion === null) {
            core.warning(
                `⏭️  No version found in ${NEWS_FILE}, cannot check the release gate`
            );
        } else if (compareVersions(newVersion, maxNewsVersion) > 0) {
            core.warning(
                `⏭️  Skipping version bump: v${newVersion} is higher than the ` +
                `highest version in ${NEWS_FILE} (v${maxNewsVersion}). ` +
                `Add a ${NEWS_FILE} entry for the new version first.`
            );
            core.setOutput('new_version', currentVersion);
            core.setOutput('bumped', 'false');
            return;
        } else {
            core.info(`✅ ${NEWS_FILE} highest version: v${maxNewsVersion}`);
        }

        // 9. Update DESCRIPTION
        await setVersion(newVersion);

        // 10. Sync the Rust crate version (same NEWS.md gate)
        updateCargoVersion(newVersion, maxNewsVersion);

        // 11. Update badges before the version commit triggers CI
        await updateReadmeBadges(newVersion);

        // 12. Set outputs
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
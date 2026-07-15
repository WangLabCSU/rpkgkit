import * as core from '@actions/core';
import { exec } from '@actions/exec';

/**
 * Check whether the test branch has commits not merged into main.
 * Returns true if test branch is ahead of main (i.e., has unmerged work).
 */
async function testBranchHasUnmergedWork(): Promise<boolean> {
  let output = '';

  try {
    // Fetch latest refs
    await exec('git', ['fetch', 'origin', 'main', 'test'], { silent: true });

    // Check if test has commits not reachable from main
    await exec('git', ['log', '--oneline', 'origin/main..origin/test'], {
      silent: true,
      listeners: {
        stdout: (data: Buffer) => {
          output += data.toString();
        },
      },
    });
  } catch {
    // If test branch doesn't exist, treat as no unmerged work
    return false;
  }

  // If there's output, test has commits not in main
  return output.trim().length > 0;
}

/**
 * Main execution
 */
async function run(): Promise<void> {
  try {
    core.startGroup('🔍 Checking test branch status');

    const hasUnmerged = await testBranchHasUnmergedWork();

    if (hasUnmerged) {
      core.info(
        '⏭️  Test branch has unmerged changes — skipping sync to avoid losing work.'
      );
      core.setOutput('synced', 'false');
      core.endGroup();
      return;
    }

    core.info('✅ Test branch has no unmerged work — proceeding with sync.');
    core.endGroup();

    // ── Force-push main to test ──
    core.startGroup('🔄 Syncing main → test');

    await exec('git', [
      'push',
      '--force',
      'origin',
      `HEAD:refs/heads/test`,
    ]);

    core.endGroup();

    core.info('🎉 Successfully synced main branch to test branch.');
    core.setOutput('synced', 'true');
  } catch (error) {
    if (error instanceof Error) {
      core.setFailed(`❌ Failed: ${error.message}`);
    } else {
      core.setFailed('❌ Unknown error');
    }
  }
}

run();

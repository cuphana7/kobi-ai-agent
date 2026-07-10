#!/usr/bin/env node

/**
 * Frism Configuration Management (CM) Client Wrapper
 * This script runs in Node.js and wraps the Java CmCli tool.
 * It automatically configures the classpath, license path, and launches Java.
 */

const { spawn } = require('child_process');
const path = require('path');

const skillDir = path.resolve(__dirname, '..');
const binDir = path.join(skillDir, 'bin');
const libDir = path.join(skillDir, 'lib');

// Classpath construction
const cpParts = [
  skillDir,
  binDir,
  path.join(libDir, 'com.fowave.frism.api.all.3.0.1-7.jar'),
  path.join(libDir, 'com.kbcard.frism.api.jar'),
  path.join(libDir, 'ojdbc8.jar'),
  path.join(libDir, 'orai18n.jar')
];

const classpath = cpParts.join(process.platform === 'win32' ? ';' : ':');

const argv = process.argv.slice(2);

if (argv.length === 0 || argv.includes('--help') || argv.includes('-h') || argv[0] === 'help') {
  printUsage();
  process.exit(0);
}

function printUsage() {
  console.log(`
Frism Configuration Management (CM) CLI Wrapper Tool

Usage:
  node frism-cm.cjs <command> [options]

Core Commands:
  connect                       Test connection and authenticate with Frism.
  get-cm                        Retrieve/create a CM package by ID.
  get-repo-id                   Find repository ID by repository name.
  check-in                      Check in a file/resource to CM.
  check-out                     Check out a file/resource from CM.
  get-file-id                   Get file/resource ID by path and name.
  check-out-cancel              Cancel checkout of a file/resource.
  get-versions                  Fetch historical version list of a resource.
  download-resource             Download a specific version of a resource.
  deploy-stage                  Deploy CM package to staging/test environment.
  deploy-real                   Deploy CM package to production environment.
  get-cm-list                   Fetch list of CM packages under a user.
  get-checkout-user             Find who currently has a resource checked out.

Options:
  --userId <id>                 Frism user ID (e.g., MT00201 - Employee Number) [Required for most commands]
  --cmId <id>                   CM Package ID (e.g., UBW260407, or leave empty for auto-creation)
  --repoName <name>             Repository name (e.g., UBW_WEB)
  --filePath <path>             File path in CM (e.g., /src/com/kbcard/ext/common/)
  --fileName <name>             File name (e.g., ClassWatchServlet.java)
  --isNew <true|false>          Whether it's a new file registration (default: false)
  --isCrc <true|false>          Whether to use CRC check (default: false)
  --isOverride <true|false>     Whether to override existing local file (default: false)
  --desc <description>          CM change description (default: kobi system modification)
  --version <version>           Specific version number to download (e.g., 1.1)
  --downloadPath <path>         Destination directory to download the resource file
  --deployTime <YYYYMMDDHHMM>   Scheduled deployment time for production (default: current time)
  --cmPackageName <name>        Filter for CM package names
  `);
}

// Prepare Java Arguments
const javaArgs = [
  `-Dfrism.license.path=${path.join(skillDir, 'license')}`,
  '-classpath', classpath,
  'com.kbcard.cm.cli.CmCli',
  ...argv
];

const javaProcess = spawn('java', javaArgs, {
  cwd: skillDir,
  env: process.env
});

let stdout = '';
let stderr = '';

javaProcess.stdout.on('data', (data) => {
  stdout += data.toString();
});

javaProcess.stderr.on('data', (data) => {
  stderr += data.toString();
});

javaProcess.on('close', (code) => {
  if (code !== 0) {
    if (stdout.trim().startsWith('{')) {
      console.log(stdout.trim());
    } else {
      console.log(JSON.stringify({
        success: false,
        errorCode: "JAVA_EXIT_ERROR",
        errorMessage: `Java process exited with code ${code}`,
        errorDetail: stderr.trim() || stdout.trim()
      }));
    }
  } else {
    console.log(stdout.trim());
  }
});

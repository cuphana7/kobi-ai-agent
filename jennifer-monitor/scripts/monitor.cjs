#!/usr/bin/env node

/**
 * Jennifer APM OpenAPI Monitor Client (v1 & v2 Unified)
 * This script runs in the Node.js runtime to query Jennifer APM OpenAPI endpoints.
 */

const http = require('http');
const https = require('https');

// Default Connection Settings (Can be overridden by environment variables or CLI arguments)
const DEFAULT_URL = process.env.JENNIFER_URL || "http://10.95.252.10:7900";
const DEFAULT_TOKEN = process.env.JENNIFER_TOKEN || "RLf7MMrrU5s";

function printUsage() {
  console.log(`
Jennifer APM OpenAPI Monitoring CLI Tool (v1 & v2 Unified)

Usage:
  node monitor.cjs <command> [options]

Core Commands (v1 & v2):
  test-connection               Test authentication and connectivity to Jennifer Server.
  get-boundaries                Fetch active service execution elapsed time boundaries (color thresholds).
  get-domains                   Fetch list of all domains.
  get-instances                 Fetch list of instances for a specific domain.
  get-realtime-domain           Fetch live, real-time metrics of a domain (TPS, active services, CPU).
  get-realtime-instance         Fetch live, real-time metrics of a specific instance.
  get-active-services           Fetch live, currently running active services.
  get-profile                   Fetch the execution profile (trace/call stack) text of a transaction by TXID.
  get-dbsearch-errors           Search historical exception errors within a time range.
  get-dbsearch-events           Search historical alert events within a time range.
  get-errors                    Fetch event rule error configurations for a specific domain.
  get-metrics                   Fetch metric-based event rule configurations.
  get-comparisons               Fetch comparison event rules (e.g., comparing to previous week).
  get-active-detail             Fetch detailed information for a single active service transaction (v2).
  get-instance                  Find instance by hostname and process ID (v2).

Options:
  --url <url>                   Jennifer View Server URL (default: ${DEFAULT_URL})
  --token <token>               API Token (default: ${DEFAULT_TOKEN})
  --domain <id>                 Domain ID (required for most queries, e.g., 7002, 1000)
  --instance <id>               Instance ID (for instance queries, defaults to 0 for domain-wide)
  --type <type>                 Target type for metrics/comparisons: 'domain', 'instance', or 'business'
  --tx <txId>                   Transaction ID (for profiling or active service detail)
  --session <sessionId>         Agent Session ID (for active service detail)
  --hash <threadHash>           Thread Hash (for active service detail)
  --pid <processId>             Process ID of the JVM/process (for instance query)
  --hostname <hostname>         Hostname of the server (for instance query)
  --start <time>                Start time for search queries (Unix millisecond, or YYYYMMddHHmm auto-parsed to 13-digit)
  --end <time>                  End time for search queries (Unix millisecond, or YYYYMMddHHmm auto-parsed to 13-digit)
  --time <time>                 Specific transaction time for profile queries (Unix millisecond, or YYYYMMddHHmm auto-parsed to 13-digit)
  --error-type <type>           Filter for specific error types (e.g., AGENT_STOP)
  --level <levels>              Comma-separated event levels to search (normal, warning, fatal)
  `);
}

// Custom request helper using built-in http/https module for 100% compatibility across all Node versions
function makeRequest(urlStr, token, method = 'GET', postData = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(urlStr);
    const options = {
      method: method,
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      timeout: 10000 // 10s timeout
    };

    const protocol = url.protocol === 'https:' ? https : http;
    const req = protocol.request(url, options, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          body: data
        });
      });
    });

    req.on('error', (err) => {
      reject(err);
    });

    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timed out after 10 seconds'));
    });

    if (postData) {
      req.write(JSON.stringify(postData));
    }
    req.end();
  });
}

// Helper to convert inputs (like YYYYMMddHHmm or 10-digit timestamps) to 13-digit Unix millisecond timestamps
function parseToTimestamp(timeStr) {
  if (!timeStr) return timeStr;
  const str = String(timeStr).trim();

  // If it's already a 13-digit millisecond timestamp
  if (/^\d{13}$/.test(str)) {
    return str;
  }

  // If it's a 10-digit second timestamp
  if (/^\d{10}$/.test(str)) {
    return String(Number(str) * 1000);
  }

  // If it's YYYYMMddHHmm (12 digits) e.g., 202606301530
  if (/^\d{12}$/.test(str)) {
    const year = parseInt(str.slice(0, 4), 10);
    const month = parseInt(str.slice(4, 6), 10) - 1; // 0-indexed month
    const day = parseInt(str.slice(6, 8), 10);
    const hour = parseInt(str.slice(8, 10), 10);
    const minute = parseInt(str.slice(10, 12), 10);
    const date = new Date(year, month, day, hour, minute);
    return String(date.getTime());
  }

  // Fallback to JS default Date parser
  const parsed = Date.parse(str);
  if (!isNaN(parsed)) {
    return String(parsed);
  }

  return str;
}

async function main() {
  const argv = process.argv.slice(2);
  if (argv.length === 0 || argv.includes('--help') || argv.includes('-h')) {
    printUsage();
    process.exit(0);
  }

  const command = argv[0];
  const args = {};

  // Parse command line options
  for (let i = 1; i < argv.length; i++) {
    const arg = argv[i];
    if (arg.startsWith('--')) {
      const key = arg.slice(2);
      const val = argv[i + 1];
      if (val && !val.startsWith('--')) {
        args[key] = val;
        i++;
      } else {
        args[key] = true;
      }
    }
  }

  const urlBase = (args.url || DEFAULT_URL).replace(/\/$/, "");
  const token = args.token || DEFAULT_TOKEN;

  try {
    switch (command) {
      case 'test-connection': {
        const urlv2 = `${urlBase}/api-v2/auth-test`;
        const urlv1 = `${urlBase}/api/domain`;
        console.log(`[Jennifer APM] Connection testing using v2 auth-test first...`);
        try {
          const res = await makeRequest(urlv2, token);
          if (res.statusCode === 200 && res.body.trim() === 'OK') {
            console.log(`SUCCESS: Jennifer View Server is reachable and authenticated successfully (v2 auth-test: OK).`);
            process.exit(0);
          }
        } catch (e) {
          console.log(`[Jennifer APM] v2 auth-test failed or unavailable: ${e.message}. Falling back to v1 domain inquiry...`);
        }

        console.log(`[Jennifer APM] Connection testing using v1 domain inquiry...`);
        const resV1 = await makeRequest(urlv1, token);
        if (resV1.statusCode === 200) {
          console.log(`SUCCESS: Jennifer View Server is reachable and authenticated successfully (v1 domain list retrieved).`);
          process.exit(0);
        } else {
          console.error(`FAILURE: Connection test failed. HTTP Status: ${resV1.statusCode}. Response: ${resV1.body}`);
          process.exit(1);
        }
      }

      case 'get-boundaries': {
        const url = `${urlBase}/api-v2/manage/rule/active-service-color-range-boundary`;
        console.log(`[Jennifer APM] Fetching active service color boundaries...`);
        const res = await makeRequest(url, token);
        if (res.statusCode === 200) {
          try {
            const data = JSON.parse(res.body);
            console.log(`SUCCESS: Active service response-time boundaries found.`);
            console.log(`- Blue / Light Green Boundary: ${data[0]} ms`);
            console.log(`- Light Green / Orange Boundary: ${data[1]} ms`);
            console.log(`- Orange / Red Boundary: ${data[2]} ms`);
            console.log(`\nRaw Output:\n${JSON.stringify(data, null, 2)}`);
            process.exit(0);
          } catch (e) {
            console.log(`Raw Response:\n${res.body}`);
            process.exit(0);
          }
        } else {
          console.error(`FAILURE: Unable to fetch boundaries. HTTP Status: ${res.statusCode}. Response: ${res.body}`);
          process.exit(1);
        }
      }

      case 'get-domains': {
        const url = `${urlBase}/api/domain`;
        console.log(`[Jennifer APM] Fetching Domain list...`);
        const res = await makeRequest(url, token);
        if (res.statusCode === 200) {
          try {
            const data = JSON.parse(res.body);
            console.log(`SUCCESS: Domains retrieved.`);
            console.log(JSON.stringify(data, null, 2));
            process.exit(0);
          } catch (e) {
            console.log(`Raw Response:\n${res.body}`);
            process.exit(0);
          }
        } else {
          console.error(`FAILURE: Failed to fetch domains. HTTP Status: ${res.statusCode}. Response: ${res.body}`);
          process.exit(1);
        }
      }

      case 'get-instances': {
        const domainId = args.domain;
        if (!domainId) {
          console.error("ERROR: --domain <domainId> option is required.");
          process.exit(1);
        }
        const url = `${urlBase}/api/instance?domain_id=${domainId}`;
        console.log(`[Jennifer APM] Fetching Instances for Domain ID: ${domainId}...`);
        const res = await makeRequest(url, token);
        if (res.statusCode === 200) {
          try {
            const data = JSON.parse(res.body);
            console.log(`SUCCESS: Instances retrieved.`);
            console.log(JSON.stringify(data, null, 2));
            process.exit(0);
          } catch (e) {
            console.log(`Raw Response:\n${res.body}`);
            process.exit(0);
          }
        } else {
          console.error(`FAILURE: Failed to fetch instances. HTTP Status: ${res.statusCode}. Response: ${res.body}`);
          process.exit(1);
        }
      }

      case 'get-realtime-domain': {
        const domainId = args.domain;
        if (!domainId) {
          console.error("ERROR: --domain <domainId> option is required.");
          process.exit(1);
        }
        const url = `${urlBase}/api/realtime/domain?domain_id=${domainId}`;
        console.log(`[Jennifer APM] Fetching Real-time Domain stats for Domain ID: ${domainId}...`);
        const res = await makeRequest(url, token);
        if (res.statusCode === 200) {
          try {
            const data = JSON.parse(res.body);
            console.log(`SUCCESS: Real-time Domain stats retrieved.`);
            console.log(JSON.stringify(data, null, 2));
            process.exit(0);
          } catch (e) {
            console.log(`Raw Response:\n${res.body}`);
            process.exit(0);
          }
        } else {
          console.error(`FAILURE: Failed to fetch real-time domain stats. HTTP Status: ${res.statusCode}. Response: ${res.body}`);
          process.exit(1);
        }
      }

      case 'get-realtime-instance': {
        const domainId = args.domain;
        const instanceId = args.instance || 0;
        if (!domainId) {
          console.error("ERROR: --domain <domainId> option is required.");
          process.exit(1);
        }
        const url = `${urlBase}/api/realtime/instance?domain_id=${domainId}&instance_id=${instanceId}`;
        console.log(`[Jennifer APM] Fetching Real-time Instance stats for Domain: ${domainId}, Instance: ${instanceId}...`);
        const res = await makeRequest(url, token);
        if (res.statusCode === 200) {
          try {
            const data = JSON.parse(res.body);
            console.log(`SUCCESS: Real-time Instance stats retrieved.`);
            console.log(JSON.stringify(data, null, 2));
            process.exit(0);
          } catch (e) {
            console.log(`Raw Response:\n${res.body}`);
            process.exit(0);
          }
        } else {
          console.error(`FAILURE: Failed to fetch real-time instance stats. HTTP Status: ${res.statusCode}. Response: ${res.body}`);
          process.exit(1);
        }
      }

      case 'get-active-services': {
        const domainId = args.domain;
        const instanceId = args.instance || 0;
        if (!domainId) {
          console.error("ERROR: --domain <domainId> option is required.");
          process.exit(1);
        }
        const url = `${urlBase}/api/activeService/list?domain_id=${domainId}&instance_id=${instanceId}`;
        console.log(`[Jennifer APM] Fetching Real-time Active Services for Domain: ${domainId}, Instance: ${instanceId}...`);
        const res = await makeRequest(url, token);
        if (res.statusCode === 200) {
          try {
            const data = JSON.parse(res.body);
            console.log(`SUCCESS: Active services retrieved.`);
            console.log(JSON.stringify(data, null, 2));
            process.exit(0);
          } catch (e) {
            console.log(`Raw Response:\n${res.body}`);
            process.exit(0);
          }
        } else {
          console.error(`FAILURE: Failed to fetch active services. HTTP Status: ${res.statusCode}. Response: ${res.body}`);
          process.exit(1);
        }
      }

      case 'get-profile': {
        const domainId = args.domain;
        const txId = args.tx;
        const rawTime = args.time;

        if (!domainId || !txId || !rawTime) {
          console.error("ERROR: --domain, --tx, and --time options are required.");
          process.exit(1);
        }

        const time = parseToTimestamp(rawTime);
        let url = `${urlBase}/api/transaction/profile.txt?domain_id=${domainId}&txid=${txId}&time=${time}`;
        console.log(`[Jennifer APM] Fetching Transaction Profile for Domain: ${domainId}, TXID: ${txId}, Time: ${time}...`);
        const res = await makeRequest(url, token);
        if (res.statusCode === 200) {
          console.log(`SUCCESS: Transaction Profile retrieved.`);
          console.log(res.body);
          process.exit(0);
        } else {
          console.error(`FAILURE: Failed to fetch transaction profile. HTTP Status: ${res.statusCode}. Response: ${res.body}`);
          process.exit(1);
        }
      }

      case 'get-dbsearch-errors': {
        const domainId = args.domain;
        const rawStart = args.start;
        const rawEnd = args.end;
        const errorType = args['error-type'];
        const instanceId = args.instance;

        if (!domainId || !rawStart || !rawEnd) {
          console.error("ERROR: --domain, --start, and --end options are required.");
          process.exit(1);
        }

        const startTime = parseToTimestamp(rawStart);
        const endTime = parseToTimestamp(rawEnd);
        let url = `${urlBase}/api/dbsearch/error?domain_id=${domainId}&start_time=${startTime}&end_time=${endTime}`;
        if (errorType) url += `&error_type=${errorType}`;
        if (instanceId) url += `&instance_id=${instanceId}`;

        console.log(`[Jennifer APM] Fetching historical errors for Domain ID: ${domainId} (Start: ${startTime}, End: ${endTime})...`);
        const res = await makeRequest(url, token);
        if (res.statusCode === 200) {
          try {
            const data = JSON.parse(res.body);
            console.log(`SUCCESS: Historical errors retrieved.`);
            console.log(JSON.stringify(data, null, 2));
            process.exit(0);
          } catch (e) {
            console.log(`Raw Response:\n${res.body}`);
            process.exit(0);
          }
        } else {
          console.error(`FAILURE: Failed to fetch historical errors. HTTP Status: ${res.statusCode}. Response: ${res.body}`);
          process.exit(1);
        }
      }

      case 'get-dbsearch-events': {
        const domainId = args.domain;
        const rawStart = args.start;
        const rawEnd = args.end;
        const level = args.level;
        const instanceId = args.instance;

        if (!domainId || !rawStart || !rawEnd) {
          console.error("ERROR: --domain, --start, and --end options are required.");
          process.exit(1);
        }

        const startTime = parseToTimestamp(rawStart);
        const endTime = parseToTimestamp(rawEnd);
        let url = `${urlBase}/api/dbsearch/event?domain_id=${domainId}&start_time=${startTime}&end_time=${endTime}`;
        if (level) url += `&level=${level}`;
        if (instanceId) url += `&instance_id=${instanceId}`;

        console.log(`[Jennifer APM] Fetching historical events for Domain ID: ${domainId} (Start: ${startTime}, End: ${endTime})...`);
        const res = await makeRequest(url, token);
        if (res.statusCode === 200) {
          try {
            const data = JSON.parse(res.body);
            console.log(`SUCCESS: Historical events retrieved.`);
            console.log(JSON.stringify(data, null, 2));
            process.exit(0);
          } catch (e) {
            console.log(`Raw Response:\n${res.body}`);
            process.exit(0);
          }
        } else {
          console.error(`FAILURE: Failed to fetch historical events. HTTP Status: ${res.statusCode}. Response: ${res.body}`);
          process.exit(1);
        }
      }

      case 'get-errors': {
        const domainId = args.domain;
        if (!domainId) {
          console.error("ERROR: --domain <domainId> option is required.");
          process.exit(1);
        }
        const url = `${urlBase}/api-v2/manage/rule/event/error/${domainId}`;
        console.log(`[Jennifer APM] Fetching ERROR event rules for Domain ID: ${domainId}...`);
        const res = await makeRequest(url, token);
        if (res.statusCode === 200) {
          const data = JSON.parse(res.body);
          console.log(`SUCCESS: Found ${data.length} Error Event Rules.`);
          console.log(JSON.stringify(data, null, 2));
          process.exit(0);
        } else {
          console.error(`FAILURE: Failed to fetch error rules. HTTP Status: ${res.statusCode}. Response: ${res.body}`);
          process.exit(1);
        }
      }

      case 'get-metrics': {
        const domainId = args.domain;
        const targetType = args.type || 'domain'; // domain, instance, business
        if (!domainId) {
          console.error("ERROR: --domain <domainId> option is required.");
          process.exit(1);
        }
        if (!['domain', 'instance', 'business'].includes(targetType)) {
          console.error("ERROR: --type must be 'domain', 'instance', or 'business'.");
          process.exit(1);
        }
        const url = `${urlBase}/api-v2/manage/rule/event/metric/${domainId}/${targetType}`;
        console.log(`[Jennifer APM] Fetching Metric Event rules for Domain: ${domainId}, Type: ${targetType}...`);
        const res = await makeRequest(url, token);
        if (res.statusCode === 200) {
          const data = JSON.parse(res.body);
          console.log(`SUCCESS: Found ${data.length} Metric Event Rules.`);
          console.log(JSON.stringify(data, null, 2));
          process.exit(0);
        } else {
          console.error(`FAILURE: Failed to fetch metric rules. HTTP Status: ${res.statusCode}. Response: ${res.body}`);
          process.exit(1);
        }
      }

      case 'get-comparisons': {
        const domainId = args.domain;
        const targetType = args.type || 'domain'; // domain, instance
        if (!domainId) {
          console.error("ERROR: --domain <domainId> option is required.");
          process.exit(1);
        }
        if (!['domain', 'instance'].includes(targetType)) {
          console.error("ERROR: --type must be 'domain' or 'instance'.");
          process.exit(1);
        }
        
        // Handle compare / comparing fallback as recommended in guidelines
        let url = `${urlBase}/api-v2/manage/rule/event/compare/${domainId}/${targetType}`;
        console.log(`[Jennifer APM] Fetching Comparison Event rules for Domain: ${domainId}, Type: ${targetType}...`);
        let res = await makeRequest(url, token);
        
        if (res.statusCode !== 200) {
          const fallbackUrl = `${urlBase}/api-v2/manage/rule/event/comparing/${domainId}/${targetType}`;
          console.log(`[Jennifer APM] Retrying with comparing fallback: ${fallbackUrl}...`);
          res = await makeRequest(fallbackUrl, token);
        }

        if (res.statusCode === 200) {
          const data = JSON.parse(res.body);
          console.log(`SUCCESS: Found ${data.length} Comparison Event Rules.`);
          console.log(JSON.stringify(data, null, 2));
          process.exit(0);
        } else {
          console.error(`FAILURE: Failed to fetch comparison rules. HTTP Status: ${res.statusCode}. Response: ${res.body}`);
          process.exit(1);
        }
      }

      case 'get-active-detail': {
        const domainId = args.domain;
        const txId = args.tx;
        const sessionId = args.session;
        const threadHash = args.hash;

        if (!domainId || !txId || !sessionId || !threadHash) {
          console.error("ERROR: --domain, --tx, --session, and --hash are all required.");
          process.exit(1);
        }

        const url = `${urlBase}/api-v2/active-service/detail/${domainId}/${txId}?sessionId=${sessionId}&threadHash=${threadHash}`;
        console.log(`[Jennifer APM] Querying Active Transaction Detail...`);
        const res = await makeRequest(url, token);
        if (res.statusCode === 200) {
          const data = JSON.parse(res.body);
          console.log(`SUCCESS: Active Transaction Detail retrieved.`);
          console.log(JSON.stringify(data, null, 2));
          process.exit(0);
        } else {
          console.error(`FAILURE: Failed to retrieve active detail. HTTP Status: ${res.statusCode}. Response: ${res.body}`);
          process.exit(1);
        }
      }

      case 'get-instance': {
        const pid = args.pid;
        const hostname = args.hostname;

        if (!pid || !hostname) {
          console.error("ERROR: --pid <processId> and --hostname <hostname> are required.");
          process.exit(1);
        }

        const url = `${urlBase}/api-v2/manage/instance?processId=${pid}&hostname=${hostname}`;
        console.log(`[Jennifer APM] Searching instance by processId: ${pid}, hostname: ${hostname}...`);
        const res = await makeRequest(url, token);
        if (res.statusCode === 200) {
          const data = JSON.parse(res.body);
          console.log(`SUCCESS: Instance query complete.`);
          console.log(JSON.stringify(data, null, 2));
          process.exit(0);
        } else {
          console.error(`FAILURE: Instance search failed. HTTP Status: ${res.statusCode}. Response: ${res.body}`);
          process.exit(1);
        }
      }

      default:
        console.error(`ERROR: Unknown command '${command}'.`);
        printUsage();
        process.exit(1);
    }
  } catch (err) {
    console.error(`CRITICAL ERROR: Failed to execute monitoring request.\nDetails: ${err.message}`);
    process.exit(1);
  }
}

main();

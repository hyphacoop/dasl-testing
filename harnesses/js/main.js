import fs from "fs";
import path from "path";
import * as helia from "./helia.js";
import * as atcute from "./atcute.js";

let roundtrip, invalidEncode, invalidDecode;
if (process.argv[2] === "helia") {
  roundtrip = helia.roundtrip;
  invalidEncode = helia.invalidEncode;
  invalidDecode = helia.invalidDecode;
} else if (process.argv[2] === "atcute") {
  roundtrip = atcute.roundtrip;
  invalidEncode = atcute.invalidEncode;
  invalidDecode = atcute.invalidDecode;
} else {
  throw new Error("provide argument (helia, atcute)");
}

async function main() {
  const results = {};

  try {
    const fixturesDir = "../../fixtures/cbor/";
    const files = await walkDir(fixturesDir);

    for (const file of files) {
      if (!file.endsWith(".json")) continue;

      const data = await fs.promises.readFile(file, "utf8");
      const tests = JSON.parse(data);
      results[path.basename(file)] = await runTests(tests);
    }

    process.stdout.write(JSON.stringify(results));
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}

/**
 * Walk a directory recursively and return all file paths
 * @param {string} dir - Directory to walk
 * @returns {Promise<string[]>} - Array of file paths
 */
async function walkDir(dir) {
  const files = [];

  async function walk(currentPath) {
    const entries = await fs.promises.readdir(currentPath, {
      withFileTypes: true,
    });

    for (const entry of entries) {
      const entryPath = path.join(currentPath, entry.name);

      if (entry.isDirectory()) {
        await walk(entryPath);
      } else {
        files.push(entryPath);
      }
    }
  }

  await walk(dir);
  return files;
}

async function runTests(tests) {
  const results = [];

  for (const test of tests) {
    let testData = Buffer.from(test.data, "hex");
    let failed, info;

    switch (test.type) {
      case "roundtrip":
        try {
          const output = Buffer.from(await roundtrip(testData));
          if (Buffer.compare(testData, output) === 0) {
            // Encoding matches expected output
            results.push({ pass: true });
          } else {
            results.push({
              pass: false,
              output: output.toString("hex"),
            });
          }
        } catch (err) {
          results.push({
            pass: false,
            error: err.message,
          });
        }
        break;

      case "invalid_in":
        [failed, info] = await invalidDecode(testData);
        if (failed) {
          // Failed to decode an invalid input, so the test passes
          results.push({
            pass: true,
            error: info, // expected error
          });
        } else {
          results.push({
            pass: false,
          });
        }
        break;

      case "invalid_out":
        [failed, info] = await invalidEncode(testData);
        if (failed) {
          // Failed to encode invalid data, so the test passes
          results.push({
            pass: true,
            error: info, // expected error
          });
        } else {
          results.push({
            pass: false,
          });
        }
        break;

      default:
        throw new Error(`Unknown test type '${test.type}'`);
    }
  }

  return results;
}

// Run the main function
main().catch((err) => {
  console.error(err);
  process.exit(1);
});

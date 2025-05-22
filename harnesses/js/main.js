import fs from "fs";
import path from "path";
import * as helia from "./helia.js";
import * as atcute from "./atcute.js";

let encode, decode, isInvalid;
if (process.argv[2] === "helia") {
  encode = helia.encode;
  decode = helia.decode;
  isInvalid = helia.isInvalid;
} else if (process.argv[2] === "atcute") {
  encode = atcute.encode;
  decode = atcute.decode;
  isInvalid = atcute.isInvalid;
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

/**
 * Run tests on a set of test cases
 * @param {TestCase[]} tests - Array of test cases
 * @returns {Promise<TestResult[]>} - Array of test results
 */
async function runTests(tests) {
  const results = [];

  for (const test of tests) {
    let testInput = Buffer.alloc(0);
    let testOutput = Buffer.alloc(0);

    if (test.input) {
      try {
        testInput = Buffer.from(test.input, "hex");
      } catch (err) {
        throw new Error(`Failed to decode hex: ${test.input}`);
      }
    }

    if (test.output) {
      try {
        testOutput = Buffer.from(test.output, "hex");
      } catch (err) {
        throw new Error(`Failed to decode hex: ${test.output}`);
      }
    }

    switch (test.type) {
      case "encode":
        try {
          const output = await encode(testInput);

          if (Buffer.compare(testOutput, output) === 0) {
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

      case "decode":
        try {
          const output = await decode(testInput);

          if (Buffer.compare(testInput, output) === 0) {
            // Decode and re-encode didn't change the input
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

      case "invalid":
        const [failed, info] = await isInvalid(testInput);
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

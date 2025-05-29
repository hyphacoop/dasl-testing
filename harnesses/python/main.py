import json
import os
import sys
from pathlib import Path

if sys.argv[1] == "dag-cbrrr":
    from dagcbrrr import roundtrip, invalid_decode, invalid_encode
elif sys.argv[1] == "libipld":
    from ipld import roundtrip, invalid_decode, invalid_encode
else:
    raise Exception("unknown library name")


def main():
    results = {}

    fixtures_dir = Path("../../fixtures/cbor/")
    for file_path in walk_dir(fixtures_dir):
        if not file_path.suffix == ".json":
            continue
        with open(file_path, "r", encoding="utf-8") as f:
            tests = json.load(f)

        results[file_path.name] = run_tests(tests)

    json.dump(results, sys.stdout, separators=(",", ":"))


def walk_dir(directory):
    """Walk a directory recursively and return all file paths"""
    files = []

    for root, dirs, filenames in os.walk(directory):
        for filename in filenames:
            files.append(Path(root) / filename)

    return files


def run_tests(tests):
    """Run tests on a set of test cases"""
    results = []

    for test in tests:
        test_data = bytes.fromhex(test["data"])

        if test["type"] == "roundtrip":
            try:
                output = roundtrip(test_data)
                if test_data == output:
                    # Encoding matches expected output
                    results.append({"pass": True})
                else:
                    results.append({"pass": False, "output": output.hex()})
            except Exception as err:
                results.append({"pass": False, "error": str(err)})

        elif test["type"] == "invalid_in":
            failed, info = invalid_decode(test_data)
            if failed:
                # Failed to decode an invalid input, so the test passes
                results.append(
                    {
                        "pass": True,
                        "error": info,  # expected error
                    }
                )
            else:
                results.append({"pass": False})

        elif test["type"] == "invalid_out":
            failed, info = invalid_encode(test_data)
            if failed:
                # Failed to encode invalid data, so the test passes
                results.append(
                    {
                        "pass": True,
                        "error": info,  # expected error
                    }
                )
            else:
                results.append({"pass": False})

        else:
            raise ValueError(f"Unknown test type '{test['Type']}'")

    return results


if __name__ == "__main__":
    main()

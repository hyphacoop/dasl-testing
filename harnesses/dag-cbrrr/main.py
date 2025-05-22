import json
import os
import sys
from pathlib import Path

import cbor2
import cbrrr


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
        test_input = bytes()
        test_output = bytes()

        if test.get("input"):
            test_input = bytes.fromhex(test["input"])

        if test.get("output"):
            test_output = bytes.fromhex(test["output"])

        if test["type"] == "encode":
            try:
                output = encode(test_input)
                if test_output == output:
                    # Encoding matches expected output
                    results.append({"pass": True})
                else:
                    results.append({"pass": False, "output": output.hex()})
            except Exception as err:
                results.append({"pass": False, "error": str(err)})

        elif test["type"] == "decode":
            try:
                output = decode(test_input)
                if test_input == output:
                    # Decode and re-encode didn't change the input
                    results.append({"pass": True})
                else:
                    results.append({"pass": False, "output": output.hex()})
            except Exception as err:
                results.append({"pass": False, "error": str(err)})

        elif test["type"] == "invalid":
            failed, info = is_invalid(test_input)
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

        else:
            raise ValueError(f"Unknown test type '{test['Type']}'")

    return results


def encode(data):
    obj = cbor2.loads(data)
    return cbrrr.encode_dag_cbor(obj)


def decode(data):
    obj = cbrrr.decode_dag_cbor(data)
    return cbrrr.encode_dag_cbor(obj)


def is_invalid(data):
    try:
        cbrrr.decode_dag_cbor(data)
        return False, ""
    except Exception as err:
        return True, str(err)


if __name__ == "__main__":
    main()

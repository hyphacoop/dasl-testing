import sys
import json
import os
from datetime import datetime, timezone
from collections import namedtuple
import jinja2

loader = jinja2.FileSystemLoader("./template.html")
env = jinja2.Environment(loader=loader, autoescape=True)
template = env.get_template("")

libs = []  # {name, link, version}
tests_by_file = []  # {name: "file", "results": [TestResult, TestResult, ...], ...}
tests_by_tag = []  # {name: "tag", "results": [TestResult, TestResult, ...], ...}
TestResult = namedtuple(
    "TestResult",
    ["type", "data", "name", "tags", "desc", "bools", "details", "file", "id"],
    defaults=("",),
)
summary = {
    "Basic": {},  # {"lib name": {"pass": 23, "fail": 5, "skip": 2}}
    "dag-cbor": {},
}

# Force some ordering
tests_by_tag.append({"name": "basic", "results": []})
tests_by_tag.append({"name": "dag-cbor", "results": []})

with open(sys.argv[1], "r") as f:
    results = json.load(f)

for lib_name, data in results.items():
    libs.append(
        {
            "name": lib_name,
            "link": data["metadata"]["link"],
            "version": data["metadata"]["version"],
        }
    )

for test_file in results[libs[0]["name"]]["files"].keys():
    with open(os.path.join("..", "fixtures", "cbor", test_file), "r") as f:
        tests = json.load(f)
    test_results = []
    for i, test in enumerate(tests):
        og_test_tags = test["tags"]
        # Add tests by tag
        # Duplicate tests with multiple tags
        for tag in test["tags"]:
            found_tag_section = False
            for j, elem in enumerate(tests_by_tag):
                if elem["name"] == tag:
                    found_tag_section = True
                    # Turn the list of tags into CSS classes
                    test["tags"] = " ".join(og_test_tags)
                    tests_by_tag[j]["results"].append(
                        TestResult(
                            **test,
                            bools=[
                                results[lib["name"]]["files"][test_file][i]["pass"]
                                for lib in libs
                            ],
                            details=[
                                results[lib["name"]]["files"][test_file][i]
                                for lib in libs
                            ],
                            file=test_file,
                        )
                    )
            if not found_tag_section:
                # tests_by_tag doesn't have an element for this tag yet
                # Turn the list of tags into CSS classes
                test["tags"] = " ".join(og_test_tags)
                tests_by_tag.append(
                    {
                        "name": tag,
                        "results": [
                            TestResult(
                                **test,
                                bools=[
                                    results[lib["name"]]["files"][test_file][i]["pass"]
                                    for lib in libs
                                ],
                                details=[
                                    results[lib["name"]]["files"][test_file][i]
                                    for lib in libs
                                ],
                                file=test_file,
                            )
                        ],
                    }
                )

        # Turn the list of tags into CSS classes
        test["tags"] = " ".join(og_test_tags)
        # Add test results to list, to collect for tests_by_file
        test_results.append(
            TestResult(
                **test,
                bools=[
                    results[lib["name"]]["files"][test_file][i]["pass"] for lib in libs
                ],
                details=[results[lib["name"]]["files"][test_file][i] for lib in libs],
                file=test_file,
            )
        )

    tests_by_file.append({"name": test_file, "results": test_results})

# Gather summary information
for lib in libs:
    summary["Basic"][lib["name"]] = {"pass": 0, "fail": 0, "skip": 0}
    summary["dag-cbor"][lib["name"]] = {"pass": 0, "fail": 0, "skip": 0}
for item in tests_by_file:
    for result in item["results"]:
        tags = result.tags.split(" ")
        if "basic" in tags:
            for i, b in enumerate(result.bools):
                if b is None:
                    summary["Basic"][libs[i]["name"]]["skip"] += 1
                elif b:
                    summary["Basic"][libs[i]["name"]]["pass"] += 1
                else:
                    summary["Basic"][libs[i]["name"]]["fail"] += 1
        if "dag-cbor" in tags:
            for i, b in enumerate(result.bools):
                if b is None:
                    summary["dag-cbor"][libs[i]["name"]]["skip"] += 1
                elif b:
                    summary["dag-cbor"][libs[i]["name"]]["pass"] += 1
                else:
                    summary["dag-cbor"][libs[i]["name"]]["fail"] += 1

with open("dist/index.html", "w") as f:
    date = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    f.write(
        template.render(
            libs=libs,
            tests_by={"file": tests_by_file, "tag": tests_by_tag},
            date=date,
            summary=summary,
        )
    )

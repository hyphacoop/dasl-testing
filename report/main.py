import sys
import json
import os
from datetime import datetime, timezone
from collections import namedtuple
import jinja2

loader = jinja2.FileSystemLoader("./template.html")
env = jinja2.Environment(loader=loader, autoescape=True)
template = env.get_template("")

libs = []  # "lib1", "lib2"
items = []  # {name: "file", "results": [Test, Test, ...], ...}
TestResult = namedtuple(
    "TestResult", ["type", "data", "name", "tags", "desc", "bools", "details"]
)
summary = {
    "Basic": {},  # {"lib name": {"pass": 23, "fail": 5}}
    "dag-cbor": {},
}

with open(sys.argv[1], "r") as f:
    results = json.load(f)

for lib in results.keys():
    libs.append(lib)

for test_file in results[libs[0]].keys():
    with open(os.path.join("..", "fixtures", "cbor", test_file), "r") as f:
        tests = json.load(f)
    test_results = []
    for i, test in enumerate(tests):
        # Turn the list of tags into CSS classes
        test["tags"] = " ".join(test["tags"])
        test_results.append(
            TestResult(
                **test,
                bools=[results[lib][test_file][i]["pass"] for lib in libs],
                details=[results[lib][test_file][i] for lib in libs],
            )
        )
    items.append({"name": test_file, "results": test_results})

# Gather summary information
for lib in libs:
    summary["Basic"][lib] = {"pass": 0, "fail": 0}
    summary["dag-cbor"][lib] = {"pass": 0, "fail": 0}
for item in items:
    for result in item["results"]:
        tags = result.tags.split(" ")
        if "basic" in tags:
            for i, b in enumerate(result.bools):
                if b:
                    summary["Basic"][libs[i]]["pass"] += 1
                else:
                    summary["Basic"][libs[i]]["fail"] += 1
        if "dag-cbor" in tags:
            for i, b in enumerate(result.bools):
                if b:
                    summary["dag-cbor"][libs[i]]["pass"] += 1
                else:
                    summary["dag-cbor"][libs[i]]["fail"] += 1

with open("dist/index.html", "w") as f:
    date = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    f.write(template.render(libs=libs, items=items, date=date, summary=summary))

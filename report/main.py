import sys
import json
import os
from collections import namedtuple

import jinja2

loader = jinja2.FileSystemLoader("./template.html")
env = jinja2.Environment(loader=loader)
template = env.get_template("")

libs = []  # "lib1", "lib2"
items = []  # {name: "file", "results": [Test, Test, ...], ...}
TestResult = namedtuple(
    "TestResult", ["type", "data", "reason", "tags", "bools", "details"]
)

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

print(libs)
print(items)

with open("index.html", "w") as f:
    f.write(template.render(libs=libs, items=items))

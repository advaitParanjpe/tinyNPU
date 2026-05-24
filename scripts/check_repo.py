#!/usr/bin/env python3

import ast
import json
import shutil
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]

REQUIRED_FILES = (
    "README.md",
    "Makefile",
    "rtl/tinynpu_top.sv",
    "rtl/tinynpu_mac_array.sv",
    "rtl/tinynpu_scratchpad_i8.sv",
    "rtl/tinynpu_result_buffer_i32.sv",
    "rtl/tinynpu_apb_wrapper.sv",
    "tb/tb_tinynpu_top.sv",
    "tb/tb_tinynpu_apb_wrapper.sv",
    "tb/tb_tinynpu_apb_dma_model.sv",
    "model/golden_matmul.py",
    "sim/run_sim.py",
    "sim/run_apb_dma_sim.py",
    "docs/bus_protocol.md",
    "docs/coverage.md",
    "docs/dma_model.md",
    "docs/results.md",
)

GENERATED_VECTOR_JSON = "tests/test_vectors/generated_matmul_tests.json"
GENERATED_VECTOR_SVH = "tests/test_vectors/generated_matmul_tests.svh"

MERGE_MARKERS = ("<" * 7, "=" * 7, ">" * 7)
ABSOLUTE_PATH_MARKERS = ("/Users/" + "advaitparanjpe", "/home/" + "advait")
SKIP_DIRS = {".git", "build"}
TEXT_SUFFIXES = {
    ".md",
    ".py",
    ".sv",
    ".svh",
    ".ys",
    ".sh",
    ".json",
    ".gitignore",
}


class CheckRunner:
    def __init__(self):
        self.failures = 0

    def pass_check(self, name, detail=""):
        suffix = f": {detail}" if detail else ""
        print(f"PASS {name}{suffix}")

    def fail_check(self, name, detail):
        self.failures += 1
        print(f"FAIL {name}: {detail}")

    def info_check(self, name, detail):
        print(f"INFO {name}: {detail}")

    def skip_check(self, name, detail):
        print(f"SKIP {name}: {detail}")


def iter_repo_files():
    for path in sorted(REPO_ROOT.rglob("*")):
        rel_parts = path.relative_to(REPO_ROOT).parts
        if any(part in SKIP_DIRS for part in rel_parts):
            continue
        if path.is_file():
            yield path


def is_text_file(path):
    if path.name == ".gitignore":
        return True
    return path.suffix in TEXT_SUFFIXES


def read_text(path):
    return path.read_text(encoding="utf-8")


def check_required_files(runner):
    missing = [name for name in REQUIRED_FILES if not (REPO_ROOT / name).is_file()]
    if missing:
        runner.fail_check("required_files", "missing " + ", ".join(missing))
    else:
        runner.pass_check("required_files", f"{len(REQUIRED_FILES)} files present")


def check_local_artifacts(runner):
    for path in REPO_ROOT.rglob(".DS_Store"):
        if ".git" not in path.parts:
            path.unlink(missing_ok=True)
    for path in sorted(REPO_ROOT.rglob("__pycache__"), reverse=True):
        if ".git" not in path.parts:
            shutil.rmtree(path)

    ds_store = [path.relative_to(REPO_ROOT) for path in REPO_ROOT.rglob(".DS_Store") if ".git" not in path.parts]
    pycache = [path.relative_to(REPO_ROOT) for path in REPO_ROOT.rglob("__pycache__") if ".git" not in path.parts]

    if ds_store:
        runner.fail_check("no_ds_store", ", ".join(str(path) for path in ds_store))
    else:
        runner.pass_check("no_ds_store")

    if pycache:
        runner.fail_check("no_pycache", ", ".join(str(path) for path in pycache))
    else:
        runner.pass_check("no_pycache")


def check_python_syntax(runner):
    py_files = []
    for dirname in ("scripts", "model", "sim"):
        py_files.extend(sorted((REPO_ROOT / dirname).glob("*.py")))

    bad = []
    for path in py_files:
        try:
            ast.parse(read_text(path), filename=str(path))
        except SyntaxError as exc:
            bad.append(f"{path.relative_to(REPO_ROOT)}:{exc.lineno}: {exc.msg}")

    if bad:
        runner.fail_check("python_syntax", "; ".join(bad))
    else:
        runner.pass_check("python_syntax", f"{len(py_files)} files")


def check_text_markers(runner):
    merge_hits = []
    path_hits = []

    for path in iter_repo_files():
        if not is_text_file(path):
            continue
        try:
            text = read_text(path)
        except UnicodeDecodeError:
            continue

        rel = path.relative_to(REPO_ROOT)
        for marker in MERGE_MARKERS:
            if marker in text:
                merge_hits.append(f"{rel}: {marker}")
        for marker in ABSOLUTE_PATH_MARKERS:
            if marker in text:
                path_hits.append(f"{rel}: {marker}")

    if merge_hits:
        runner.fail_check("no_merge_conflict_markers", "; ".join(merge_hits))
    else:
        runner.pass_check("no_merge_conflict_markers")

    if path_hits:
        runner.fail_check("no_user_absolute_paths", "; ".join(path_hits))
    else:
        runner.pass_check("no_user_absolute_paths")


def check_todo_only_files(runner):
    todo_only = []
    for path in iter_repo_files():
        if not is_text_file(path):
            continue
        try:
            lines = [line.strip() for line in read_text(path).splitlines()]
        except UnicodeDecodeError:
            continue
        meaningful = [
            line for line in lines
            if line and line not in ("```", "```text", "```sh")
        ]
        if meaningful and all("todo" in line.lower() for line in meaningful):
            todo_only.append(str(path.relative_to(REPO_ROOT)))

    if todo_only:
        runner.fail_check("no_todo_only_files", ", ".join(todo_only))
    else:
        runner.pass_check("no_todo_only_files")


def check_generated_vectors(runner):
    json_path = REPO_ROOT / GENERATED_VECTOR_JSON
    svh_path = REPO_ROOT / GENERATED_VECTOR_SVH

    missing = [name for name in (GENERATED_VECTOR_JSON, GENERATED_VECTOR_SVH) if not (REPO_ROOT / name).is_file()]
    if missing:
        runner.fail_check("generated_vector_files", "missing " + ", ".join(missing))
        return
    runner.pass_check("generated_vector_files")

    try:
        data = json.loads(read_text(json_path))
    except json.JSONDecodeError as exc:
        runner.fail_check("generated_json_shape", f"invalid JSON: {exc}")
        return

    tests = data.get("tests")
    errors = []
    if data.get("matrix_n") != 4:
        errors.append("matrix_n != 4")
    if not isinstance(tests, list):
        errors.append("tests is not a list")
    elif len(tests) < 50:
        errors.append(f"only {len(tests)} tests")
    else:
        for idx, test in enumerate(tests):
            for key in ("A", "B", "C_expected"):
                values = test.get(key)
                if not isinstance(values, list) or len(values) != 16:
                    errors.append(f"test {idx} {key} length is not 16")
                    break
            if errors:
                break

    if errors:
        runner.fail_check("generated_json_shape", "; ".join(errors))
    else:
        runner.pass_check("generated_json_shape", f"{len(tests)} tests")


def check_optional_tools(runner):
    for tool in ("iverilog", "yosys"):
        path = shutil.which(tool)
        if path:
            runner.pass_check(f"tool_{tool}", path)
        else:
            runner.skip_check(f"tool_{tool}", "not found in PATH")


def main():
    runner = CheckRunner()
    check_required_files(runner)
    check_local_artifacts(runner)
    check_python_syntax(runner)
    check_text_markers(runner)
    check_todo_only_files(runner)
    check_generated_vectors(runner)
    check_optional_tools(runner)

    if runner.failures:
        print(f"tinyNPU repo check FAIL: {runner.failures} failed check group(s)")
        return 1

    print("tinyNPU repo check PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())

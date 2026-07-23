#!/usr/bin/env python3
"""Eval harness for lidwatch - scores project health across dimensions."""

import json
import os
import subprocess
import sys


def run(cmd, cwd=None, timeout=120):
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout, cwd=cwd
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, "", "timeout"
    except FileNotFoundError:
        return -1, "", f"command not found: {cmd[0]}"


def score_tests(project_dir):
    fw_path = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
    lib_path = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
    cmd = ["swift", "test"]
    if os.path.isdir(fw_path):
        cmd += [
            "-Xswiftc", f"-F{fw_path}",
            "-Xlinker", "-rpath", "-Xlinker", fw_path,
            "-Xlinker", "-rpath", "-Xlinker", lib_path,
        ]
    rc, stdout, stderr = run(cmd, cwd=project_dir, timeout=300)
    if rc == 0:
        return 1.0
    combined = stdout + stderr
    if "build complete" in combined.lower() or "compiled" in combined.lower():
        return 0.5
    return 0.0


def score_type_check(project_dir):
    rc, stdout, stderr = run(["swift", "build"], cwd=project_dir, timeout=300)
    if rc == 0:
        return 1.0
    combined = stdout + stderr
    if "warning" in combined.lower() and "error" not in combined.lower():
        return 0.8
    return 0.0


def score_lint(project_dir):
    rc, _, _ = run(["which", "swiftlint"])
    if rc != 0:
        sources = []
        for root, _dirs, files in os.walk(os.path.join(project_dir, "Sources")):
            for f in files:
                if f.endswith(".swift"):
                    sources.append(os.path.join(root, f))
        if not sources:
            return 0.0
        issues = 0
        total_lines = 0
        for src in sources:
            with open(src) as fh:
                lines = fh.readlines()
                total_lines += len(lines)
                for line in lines:
                    if len(line.rstrip()) > 200:
                        issues += 1
        if total_lines == 0:
            return 0.0
        issue_rate = issues / total_lines
        if issue_rate == 0:
            return 1.0
        elif issue_rate < 0.05:
            return 0.8
        elif issue_rate < 0.1:
            return 0.6
        return 0.4

    rc, stdout, _ = run(["swiftlint", "lint", "--quiet"], cwd=project_dir)
    if rc == 0:
        return 1.0
    violations = stdout.strip().count("\n") + (1 if stdout.strip() else 0)
    if violations <= 5:
        return 0.8
    elif violations <= 15:
        return 0.6
    return 0.3


def score_capability_surface(project_dir):
    score = 0.0
    total = 5

    pkg = os.path.join(project_dir, "Package.swift")
    if os.path.exists(pkg):
        with open(pkg) as f:
            content = f.read()
        if "lidwatch" in content and "LidwatchCore" in content:
            score += 1.0

    cli_dir = os.path.join(project_dir, "Sources", "lidwatch")
    if os.path.isdir(cli_dir):
        swift_files = [f for f in os.listdir(cli_dir) if f.endswith(".swift")]
        if swift_files:
            score += 1.0

    core_dir = os.path.join(project_dir, "Sources", "LidwatchCore")
    if os.path.isdir(core_dir):
        core_files = [f for f in os.listdir(core_dir) if f.endswith(".swift")]
        has_power = any(
            "PowerAssertion" in f or "power" in f.lower() for f in core_files
        )
        has_sysinfo = any(
            "SystemInfo" in f or "system" in f.lower() for f in core_files
        )
        if has_power and has_sysinfo:
            score += 1.0
        elif has_power or has_sysinfo:
            score += 0.5

    rc, stdout, stderr = run(
        ["swift", "run", "lidwatch", "help", "wrap"],
        cwd=project_dir,
        timeout=300,
    )
    if rc == 0 and "command" in (stdout + stderr).lower():
        score += 1.0

    rc, stdout, stderr = run(
        ["swift", "run", "lidwatch", "help", "status"],
        cwd=project_dir,
        timeout=300,
    )
    if rc == 0:
        score += 1.0

    return score / total


def score_observability(project_dir):
    sources = []
    for root, _dirs, files in os.walk(os.path.join(project_dir, "Sources")):
        for f in files:
            if f.endswith(".swift"):
                sources.append(os.path.join(root, f))

    if not sources:
        return 0.0

    log_indicators = ["os.Logger", "Logger(", "logger."]
    found = 0
    for src in sources:
        with open(src) as fh:
            content = fh.read()
        for indicator in log_indicators:
            if indicator in content:
                found += 1
                break

    return min(1.0, found / max(1, len(sources) * 0.5))


def main():
    project_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    dimensions = {
        "tests": score_tests(project_dir),
        "type_check": score_type_check(project_dir),
        "lint": score_lint(project_dir),
        "capability_surface": score_capability_surface(project_dir),
        "observability": score_observability(project_dir),
    }

    composite = sum(dimensions.values()) / len(dimensions)

    result = {
        "dimensions": dimensions,
        "composite": round(composite, 4),
    }

    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())

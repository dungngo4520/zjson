#!/usr/bin/env python3

import subprocess
import os
import sys
import json
from collections import defaultdict


def get_test_category(filename):
    """Determine test category from filename prefix"""
    if filename.startswith("y_"):
        return "must_accept"
    elif filename.startswith("n_"):
        return "must_reject"
    elif filename.startswith("i_"):
        return "implementation_defined"
    return "unknown"


def run_single_test(executable, test_file):
    """Run a single test file and return result"""
    try:
        result = subprocess.run(
            [executable, test_file], capture_output=True, text=True, timeout=5
        )

        output = (result.stdout + result.stderr).strip()

        if result.returncode == 0:
            if "ACCEPTED" in output:
                return {"accepted": True, "error": None}
            elif "REJECTED" in output:
                error = output.replace("REJECTED:", "").strip()
                return {"accepted": False, "error": error}
            else:
                return {"accepted": False, "error": f"Unexpected output: {output}"}
        else:
            return {
                "accepted": False,
                "error": f"CRASH/PANIC (exit code {result.returncode})",
            }
    except subprocess.TimeoutExpired:
        return {"accepted": False, "error": "TIMEOUT"}
    except Exception as e:
        return {"accepted": False, "error": f"Exception: {str(e)}"}


def main():
    # Get the directory where this script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    root_dir = os.path.join(script_dir, "..", "..")

    # Build the test runner
    print("Building test runner...")
    build_result = subprocess.run(
        [
            "zig",
            "build-exe",
            "--dep",
            "zjson",
            "-Mroot=" + os.path.join(script_dir, "json_test_single.zig"),
            "-Mzjson=" + os.path.join(root_dir, "src", "zjson.zig"),
        ],
        capture_output=True,
        text=True,
        cwd=script_dir,
    )

    if build_result.returncode != 0:
        print("Failed to build test runner:")
        print(build_result.stderr)
        return 1

    executable = os.path.join(
        script_dir, "root"
    )  # Zig names the executable after the root module
    test_dir = os.path.join(script_dir, "test_suite", "test_parsing")

    if not os.path.exists(test_dir):
        print(f"Test directory not found: {test_dir}")
        return 1

    # Collect all test files
    test_files = sorted([f for f in os.listdir(test_dir) if f.endswith(".json")])

    print(f"\nRunning JSON Test Suite from: {test_dir}")
    print(f"Found {len(test_files)} test files\n")

    results = []
    stats = {
        "must_accept": {"total": 0, "passed": 0, "failed": []},
        "must_reject": {"total": 0, "passed": 0, "failed": []},
        "implementation_defined": {"total": 0, "accepted": 0, "rejected": 0},
    }

    # Run all tests
    for i, filename in enumerate(test_files, 1):
        if i % 50 == 0:
            print(f"Progress: {i}/{len(test_files)}", end="\r")

        test_path = os.path.join(test_dir, filename)
        category = get_test_category(filename)
        result = run_single_test(executable, test_path)

        # Determine if test passed
        if category == "must_accept":
            passed = result["accepted"]
        elif category == "must_reject":
            passed = not result["accepted"]
        else:  # implementation_defined
            passed = True  # Always pass for implementation-defined

        # Update stats
        stats[category]["total"] += 1
        if category == "implementation_defined":
            if result["accepted"]:
                stats[category]["accepted"] += 1
            else:
                stats[category]["rejected"] += 1
        else:
            if passed:
                stats[category]["passed"] += 1
            else:
                stats[category]["failed"].append(
                    {
                        "filename": filename,
                        "accepted": result["accepted"],
                        "error": result["error"],
                    }
                )

        results.append(
            {
                "filename": filename,
                "category": category,
                "accepted": result["accepted"],
                "error": result["error"],
                "passed": passed,
            }
        )

    print(f"\nProgress: {len(test_files)}/{len(test_files)}")

    # Print summary
    print("\n" + "=" * 80)
    print("JSON Test Suite Results")
    print("=" * 80)
    print()

    total_tests = len(results)
    total_passed = sum(1 for r in results if r["passed"])

    print(
        f"Overall: {total_passed}/{total_tests} tests passed ({total_passed / total_tests * 100:.1f}%)\n"
    )

    # Must Accept
    ma = stats["must_accept"]
    print(
        f"Must Accept (y_): {ma['passed']}/{ma['total']} passed ({ma['passed'] / ma['total'] * 100:.1f}%)"
    )

    # Must Reject
    mr = stats["must_reject"]
    print(
        f"Must Reject (n_): {mr['passed']}/{mr['total']} passed ({mr['passed'] / mr['total'] * 100:.1f}%)"
    )

    # Implementation Defined
    im = stats["implementation_defined"]
    print(
        f"Implementation Defined (i_): {im['accepted']}/{im['total']} accepted, {im['rejected']}/{im['total']} rejected\n"
    )

    # Print failures
    print("\nFailed Tests by Category:")
    print("-" * 80)

    # Group failures by error type
    error_groups = defaultdict(list)

    for category in ["must_accept", "must_reject"]:
        if stats[category]["failed"]:
            print(
                f"\n{category.upper().replace('_', ' ')} ({len(stats[category]['failed'])} failures):"
            )
            for fail in stats[category]["failed"][:20]:  # Show first 20
                error_key = fail["error"] if fail["error"] else "No error"
                error_groups[error_key].append(fail["filename"])

            if len(stats[category]["failed"]) > 20:
                print(f"  ... and {len(stats[category]['failed']) - 20} more")

    # Print error summary
    print("\n\nError Summary:")
    print("-" * 80)
    for error, files in sorted(error_groups.items(), key=lambda x: -len(x[1]))[:10]:
        print(f"\n{error}: {len(files)} files")
        for f in files[:5]:
            print(f"  - {f}")
        if len(files) > 5:
            print(f"  ... and {len(files) - 5} more")

    # Save detailed results to file
    results_file = os.path.join(script_dir, "test_suite_results.json")
    with open(results_file, "w") as f:
        json.dump({"summary": stats, "all_results": results}, f, indent=2)

    print(f"\n\nDetailed results saved to: {results_file}")

    # Cleanup
    try:
        if os.path.exists(executable):
            os.remove(executable)
        for obj_file in [f for f in os.listdir(script_dir) if f.endswith(".o")]:
            os.remove(os.path.join(script_dir, obj_file))
    except Exception:
        pass  # Ignore cleanup errors

    # Return failure if any must_accept or must_reject tests failed
    total_failed = len(stats["must_accept"]["failed"]) + len(
        stats["must_reject"]["failed"]
    )
    if total_failed > 0:
        print(f"\nFAILED: {total_failed} tests failed")
        return 1
    else:
        print("\nSUCCESS: All must_accept and must_reject tests passed")
        return 0


if __name__ == "__main__":
    sys.exit(main() or 0)

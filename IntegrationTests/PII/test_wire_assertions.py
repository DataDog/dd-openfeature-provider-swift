# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2026-Present Datadog, Inc.

"""Verifier regression tests, not evidence of SDK execution."""
import copy
import hashlib
import unittest
import run


def fixture():
    events = []
    for state in ["absent", "false", "null", "wrong", "true"]:
        for kind in ["bool", "string", "int", "double", "object", "missing", "mismatch"]:
            code = {"missing": "FLAG_NOT_FOUND", "mismatch": "TYPE_MISMATCH"}.get(kind)
            key = "bool" if kind == "mismatch" else kind
            event = {"flag": {"key": f"{key}-{state}"}, "targeting_key": run.RAW if state == "true" else run.HASH,
                     "evaluation_count": 4 if state == "false" and kind == "bool" else 2}
            if state == "true":
                event["context"] = {"evaluation": {"private": "CONTEXT_CANARY"}}
            if code:
                event["error"] = {"message": code}
                event["runtime_default_used"] = True
            events.append(event)
    return [{"flagEvaluations": events}], [{"data": {"attributes": {"subject": {
        "targeting_key": run.RAW, "targeting_attributes": {"private": "CONTEXT_CANARY"}}}}}]


class WireAssertionsTests(unittest.TestCase):
    def test_accepts_expected_counts(self):
        self.assertEqual(run.verify_wire(*fixture())["evaluation_count"], 72)

    def test_rejects_raw_or_double_hashed_keys(self):
        for key in [run.RAW, "sha256_" + hashlib.sha256(run.HASH.encode()).hexdigest()]:
            events, requests = fixture()
            events[0]["flagEvaluations"][0]["targeting_key"] = key
            with self.assertRaises(AssertionError):
                run.verify_wire(events, requests)

    def test_rejects_context_or_raw_error_leaks(self):
        for changes in [{"context": {"evaluation": {"private": "CONTEXT_CANARY"}}},
                        {"error": {"message": "ERROR_CANARY"}}]:
            events, requests = fixture()
            events[0]["flagEvaluations"][0].update(changes)
            with self.assertRaises(AssertionError):
                run.verify_wire(events, requests)

    def test_rejects_missing_or_duplicate_emission(self):
        for duplicate in [True, False]:
            events, requests = fixture()
            if duplicate:
                events[0]["flagEvaluations"].append(copy.deepcopy(events[0]["flagEvaluations"][0]))
            else:
                events[0]["flagEvaluations"].pop()
            with self.assertRaises(AssertionError):
                run.verify_wire(events, requests)

    def test_rejects_protected_assignment_requests(self):
        events, requests = fixture()
        requests[0]["data"]["attributes"]["subject"]["targeting_key"] = run.HASH
        with self.assertRaises(AssertionError):
            run.verify_wire(events, requests)


if __name__ == "__main__":
    unittest.main()

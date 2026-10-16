"""Regression tests for the release gate, not the CAD implementation."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from verify_test_run import verify

class GateTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        (self.root/'run.complete').write_text('run-a\n')
        self.suite='trim-test'
        self.log=self.root/(self.suite+'.log')
        self.marker=self.root/(self.suite+'.done.json')
        self.log.write_text('PASS first\nPASS last\n')
        self.data={'session':'run-a','status':'complete','checks':2,'failed':0}
        self.write_marker()
    def write_marker(self): self.marker.write_text(json.dumps(self.data))
    def check(self): return verify(self.root,'run-a',{self.suite:2})
    def test_completed_suite(self): self.assertEqual(self.check()[0]['checks'],2)
    def test_successful_failure_regression_name(self):
        self.log.write_text('PASS failure-rollback\nPASS loader-fails-closed\n')
        self.assertEqual(self.check()[0]['checks'],2)
    def test_missing_completion(self):
        self.marker.unlink()
        with self.assertRaises(FileNotFoundError): self.check()
    def test_partial_pass_log(self):
        self.log.write_text('PASS first\n')
        with self.assertRaises(ValueError): self.check()
    def test_previous_run_marker(self):
        self.data['session']='run-old'; self.write_marker()
        with self.assertRaises(ValueError): self.check()
    def test_missing_script_completion(self):
        (self.root/'run.complete').unlink()
        with self.assertRaises(FileNotFoundError): self.check()
    def test_wrong_script_completion_session(self):
        (self.root/'run.complete').write_text('run-other\n')
        with self.assertRaises(ValueError): self.check()
    def test_lisp_error_after_pass(self):
        self.log.write_text('PASS first\nFAIL EXCEPTION: bad argument\n')
        with self.assertRaises(ValueError): self.check()
    def test_empty_log(self):
        self.log.write_text(''); self.data['checks']=0; self.write_marker()
        with self.assertRaises(ValueError): self.check()
    def test_embedded_smoke_failure(self):
        self.log.write_text('PASS\nSESSION_SETTINGS=FAIL\n')
        with self.assertRaises(ValueError): self.check()

if __name__=='__main__': unittest.main()

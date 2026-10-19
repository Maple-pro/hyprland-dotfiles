import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('battery',str(Path(__file__).resolve().parents[1]/'.config/hypr/scripts/battery-notify.py'))
battery=importlib.util.module_from_spec(spec);spec.loader.exec_module(battery)
class BatteryTests(unittest.TestCase):
    def test_thresholds_and_recharge(self):
        with tempfile.TemporaryDirectory() as d,patch.object(battery.subprocess,'run') as notify:
            root=Path(d);(root/'status').write_text('Discharging')
            old=0
            for percent,level,count in [(20,1,1),(19,1,1),(10,2,2),(9,2,2),(5,3,3),(4,3,3)]:
                (root/'capacity').write_text(str(percent));old=battery.check(root,old)
                self.assertEqual(old,level);self.assertEqual(notify.call_count,count)
            (root/'status').write_text('Charging');self.assertEqual(battery.check(root,old),0)
    def test_unreadable_device(self):
        with tempfile.TemporaryDirectory() as d:self.assertIsNone(battery.check(Path(d),0))
if __name__=='__main__':unittest.main(verbosity=2)

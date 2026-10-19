import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('compat', str(Path(__file__).resolve().parents[1]/'.local/lib/monique-hypr56/compat.py'))
compat=importlib.util.module_from_spec(spec);spec.loader.exec_module(compat)
compat.install()
os.environ.setdefault('HYPRLAND_INSTANCE_SIGNATURE','unit-test')
from monique.models import MonitorConfig, Profile, ResolutionMode
from monique.profile_manager import ProfileManager
from monique.hyprland import HyprlandIPC

class CompatibilityTests(unittest.TestCase):
    def test_upgrade_guard(self):
        with patch.object(compat,'version',return_value='99.0'):
            with self.assertRaisesRegex(RuntimeError,'requires 0.8.3'):compat.install()
    def test_nested_transaction_cleans_marker_on_error(self):
        with tempfile.TemporaryDirectory() as directory,patch.dict(os.environ,{'XDG_RUNTIME_DIR':directory}):
            marker=Path(directory)/'monique-applying'
            with self.assertRaises(ValueError):
                with compat.transaction():
                    self.assertEqual(marker.read_text().strip(),str(os.getpid()))
                    with compat.transaction():self.assertTrue(marker.exists())
                    raise ValueError('simulated failure')
            self.assertFalse(marker.exists())
    def profile(self,available):
        with tempfile.TemporaryDirectory() as directory:
            mgr=ProfileManager(Path(directory));mgr.save(Profile(name='test',monitors=[MonitorConfig(name='HDMI-A-1',width=1920,height=1080,refresh_rate=60)]))
            current=MonitorConfig(name='HDMI-A-1',description='new projector',available_modes=available)
            with patch('monique.utils.load_app_settings',return_value={'use_port_names':True}),patch.object(HyprlandIPC,'get_monitors',return_value=[current]):
                return mgr.load('test').monitors[0]
    def test_supported_mode_preserved(self):
        self.assertIs(self.profile(['1920x1080@59.94Hz']).resolution_mode,ResolutionMode.EXPLICIT)
    def test_unsupported_projector_uses_preferred(self):
        self.assertIs(self.profile(['1280x720@60.00Hz']).resolution_mode,ResolutionMode.PREFERRED)
    def test_mirror_source_resolved_to_name(self):
        raw=[{'id':0,'name':'eDP-1','mirrorOf':'none'},{'id':1,'name':'HDMI-A-1','mirrorOf':'0'}]
        with patch.object(HyprlandIPC,'command_json',return_value=raw):
            monitors=HyprlandIPC().get_monitors()
            self.assertEqual(monitors[1].mirror_of,'eDP-1')

if __name__=='__main__':unittest.main(verbosity=2)

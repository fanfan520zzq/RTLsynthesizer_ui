"""Active PC/HDMI scene geometry and 60K clock-contract regression."""
import os
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
import re
import tempfile
import unittest
from fractions import Fraction
from pathlib import Path
from PySide6.QtWidgets import QApplication
from designer.ui_schema import UIScene, TextWidget
from designer.ui_designer import MainWindow
from generator.compact_rtl_generator import CompactRTLGenerator

PC_ROOT = Path(__file__).resolve().parent
# Standalone D:\verilogQT can use the same tests without copying FPGA RTL.
FPGA = Path(os.environ.get('FPGA_UI_PROJECT', str(PC_ROOT.parent/'60k_ui_prj')))
APP = QApplication.instance() or QApplication([])


class PanelTests(unittest.TestCase):
    def test_new_and_missing_size_default_to_panel(self):
        for scene in (UIScene(), UIScene.from_dict({})):
            self.assertEqual((scene.width, scene.height), (800, 480))
        editor = MainWindow()
        try:
            self.assertEqual((editor.canvas.ui_scene.width,
                              editor.canvas.ui_scene.height), (800, 480))
            editor.canvas.load_scene(UIScene(width=640, height=360))
            editor.is_modified = False
            editor.on_new()
            self.assertEqual((editor.canvas.ui_scene.width,
                              editor.canvas.ui_scene.height), (800, 480))
        finally:
            editor.is_modified = False
            editor.close()

    def test_existing_explicit_resolution_is_not_silently_changed(self):
        scene = UIScene.from_dict({'width':1280, 'height':720})
        self.assertEqual((scene.width, scene.height), (1280, 720))

    def test_active_scenes_fit_panel(self):
        for name in ('autoplay_status.json', 'dimension_autoplay_pc.json'):
            scene = UIScene.from_json(PC_ROOT/'examples'/name)
            self.assertEqual((scene.width, scene.height), (800, 480))
            for w in scene.widgets:
                with self.subTest(scene=name, widget=w.name):
                    self.assertGreaterEqual(w.x, 0)
                    self.assertGreaterEqual(w.y, 0)
                    self.assertGreater(w.width, 0)
                    self.assertGreater(w.height, 0)
                    self.assertLessEqual(w.x+w.width, 800)
                    self.assertLessEqual(w.y+w.height, 480)

    def test_hdmi_labels_fit_generated_font(self):
        scene = UIScene.from_json(PC_ROOT/'examples/autoplay_status.json')
        for w in scene.widgets:
            if isinstance(w, TextWidget) and not w.source:
                scale = 2 if w.font_size >= 14 else 1
                with self.subTest(widget=w.name):
                    self.assertLessEqual(len(w.text)*8*scale, w.width)
                    self.assertLessEqual(7*scale, w.height)

    def test_checked_in_rtl_is_reproducible_single_file(self):
        scene = UIScene.from_json(PC_ROOT/'examples/autoplay_status.json')
        with tempfile.TemporaryDirectory() as folder:
            CompactRTLGenerator().generate(scene, Path(folder))
            self.assertEqual([p.name for p in Path(folder).glob('*.v')],
                             ['ui_generated_scene.v'])
            self.assertEqual((Path(folder)/'ui_generated_scene.v').read_text(),
                             (FPGA/'rtl/ui_generated_scene.v').read_text())

    def test_top_and_timing_defaults_match_reference_mode(self):
        expected = {'hlength':1056, 'vlength':525,
                    'hsync_pol':1, 'vsync_pol':1,
                    'hsync_len':20, 'hbp_len':26, 'h_visible':800,
                    'vsync_len':3, 'vbp_len':23, 'v_visible':480}
        top = (FPGA/'rtl/top_tmds_60k.v').read_text()
        timing = (FPGA/'rtl/video_timing_ctrl.v').read_text()
        for key, value in expected.items():
            self.assertRegex(top, rf'\.video_{key}\s*\({value}\)')
            self.assertRegex(timing, rf'parameter video_{key}\s*= {value}\b')
        self.assertEqual(1056-20-26-800, 210)
        self.assertEqual(525-3-23-480, 19)

    def test_plla_and_sdc_frequencies_agree(self):
        pll = (FPGA/'rtl/TMDS_PLL.v').read_text()
        p = {k:int(v) for k,v in re.findall(
            r'defparam PLLA_inst\.(\w+) = (\d+);', pll)}
        pfd = Fraction(50, p['IDIV_SEL'])
        vco = pfd * p['FBDIV_SEL'] * (
            p['MDIV_SEL']+Fraction(p['MDIV_FRAC_SEL'],8))
        self.assertTrue(19 <= pfd <= Fraction(175,2))
        self.assertTrue(700 <= vco <= 1400)
        fast = vco/(p['ODIV0_SEL']+Fraction(p['ODIV0_FRAC_SEL'],8))
        pixel = vco/p['ODIV1_SEL']
        self.assertEqual(fast/pixel, 5)
        self.assertEqual(pixel, Fraction(100,3))
        sdc = (FPGA/'constraints/tang_mega_60k_tmds.sdc').read_text()
        for name, frequency in (('clk_tmds_5x',fast),('clk_pixel',pixel)):
            m = re.search(rf'create_generated_clock -name {name} .*?'
                          r'-divide_by (\d+) -multiply_by (\d+)', sdc)
            self.assertIsNotNone(m)
            self.assertEqual(Fraction(50*int(m[2]),int(m[1])), frequency)
        self.assertLess(abs(float(pixel)-33.3)/33.3, .0011)


if __name__ == '__main__':
    unittest.main()

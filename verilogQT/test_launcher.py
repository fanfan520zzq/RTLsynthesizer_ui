"""Menu and real BAT wiring regression without GUI/serial side effects."""
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from tools import launcher


class LauncherTests(unittest.TestCase):
    def test_mode_commands(self):
        for mode in ('scene-control','designer','dimension','loopback'):
            command = launcher.command_for(mode)
            self.assertEqual(command[:2], [str(launcher.ROOT/'.venv/Scripts/python.exe'),
                                           str(launcher.ROOT/'run.py')])
            self.assertEqual(command[2:], [] if mode=='designer' else ['--'+mode])
        self.assertTrue(launcher.command_for('generate')[1].endswith('generate_dx7_rtl.py'))

    def test_custom_scene_and_unknown_mode(self):
        command = launcher.command_for('scene-control', 'examples/dimension_autoplay_pc.json')
        self.assertEqual(command[-2], '--scene')
        with self.assertRaises(ValueError): launcher.command_for('invented')
        with self.assertRaises(ValueError): launcher.command_for('dimension', 'scene.json')

    def test_dry_run_never_starts_a_process(self):
        with patch.object(launcher.subprocess,'run') as run, patch.object(launcher.subprocess,'Popen') as popen:
            for mode in launcher.MODES:
                self.assertEqual(launcher.run_mode(mode,dry_run=True),0)
            run.assert_not_called()
            popen.assert_not_called()

    def test_menu_selection_and_advanced(self):
        with patch('builtins.input',side_effect=['bad','1','2','3','4','1','4','2','4','0','0']), patch.object(launcher,'run_mode',return_value=0) as run:
            self.assertEqual(launcher.menu(),0)
            self.assertEqual([c.args[0] for c in run.call_args_list],
                             ['scene-control','designer','dimension','loopback','generate'])

    def test_eof_exits(self):
        with patch('builtins.input',side_effect=EOFError):
            self.assertEqual(launcher.menu(),0)

    def test_failure_propagation_and_working_directory(self):
        with patch.object(launcher.subprocess,'run',return_value=subprocess.CompletedProcess([],7)) as run:
            self.assertEqual(launcher.run_mode('designer'),7)
            self.assertEqual(run.call_args.kwargs['cwd'],launcher.ROOT)

    def test_real_bat_from_unrelated_directory_with_spaces(self):
        with tempfile.TemporaryDirectory(prefix='launcher space ') as cwd:
            for mode in ('designer','scene-control','dimension','loopback','generate'):
                with self.subTest(mode=mode):
                    result = subprocess.run(['cmd.exe','/d','/c',str(launcher.ROOT/'启动.bat'),
                                             '--mode',mode,'--dry-run'],cwd=cwd,
                                            stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,
                                            stderr=subprocess.STDOUT,encoding='utf-8',errors='replace',timeout=15)
                    self.assertEqual(result.returncode,0,result.stdout)
                    self.assertIn('DRY_RUN',result.stdout)
                    self.assertIn(str(launcher.ROOT/'run.py') if mode!='generate' else 'generate_dx7_rtl.py',result.stdout)

    def test_only_one_root_bat(self):
        self.assertEqual([p.name for p in launcher.ROOT.glob('*.bat')],['启动.bat'])

    def test_real_menu_utf8(self):
        result = subprocess.run(['cmd.exe','/d','/c',str(launcher.ROOT/'启动.bat')],
                                input='0\n',stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
                                encoding='utf-8',errors='strict',timeout=15)
        self.assertEqual(result.returncode,0,result.stdout)
        self.assertIn('运行 UI',result.stdout)
        self.assertIn('编辑 UI',result.stdout)
        self.assertNotIn('\ufffd',result.stdout)

    def test_relocated_aliases_and_scene_argument(self):
        aliases = launcher.ROOT/'tools/legacy_launchers'
        for name in ('start.bat','start_scene_control.bat','start_dimension.bat',
                     'start_loopback.bat','LEGACY_START.bat','START_ENV_V1.bat'):
            args = ['--dry-run']
            if name in ('start.bat','LEGACY_START.bat','START_ENV_V1.bat'):
                args += ['--mode','designer']
            if name == 'start_scene_control.bat':
                args += ['--scene',str(launcher.ROOT/'examples/scene with spaces.json')]
            result = subprocess.run(['cmd.exe','/d','/c',str(aliases/name),*args],
                                    stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT,encoding='utf-8',errors='strict',timeout=15)
            self.assertEqual(result.returncode,0,result.stdout)
            self.assertIn('DRY_RUN',result.stdout)
            if name == 'start_scene_control.bat':
                self.assertIn('scene with spaces.json',result.stdout)


if __name__ == '__main__': unittest.main()

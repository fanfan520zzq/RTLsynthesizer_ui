"""Offscreen GUI checks exercise response-to-scene linkage and real entry points."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
import sys
from pathlib import Path
sys.path.insert(0,os.path.join(os.path.dirname(__file__),'designer'))
from PySide6.QtWidgets import QApplication
from communication.protocol import Reply
from designer.loopback_window import LoopbackWindow

app=QApplication.instance() or QApplication([])
window=LoopbackWindow()
assert window.known_slots == set()
window.target.setValue(45000)
assert window.state.get_knob_value(0)==0  # local edit cannot fake hardware confirmation
window.accept_reply(Reply(1,0,0,32768,1))
assert window.state.get_knob_value(0)==32768
assert window.known_slots=={0}
assert '32768' in window.confirmed_value.text()
window.link_changed(False)
assert not window.known_slots
assert window.state.get_knob_value(0)==0
window.show()
app.processEvents()
output_dir=Path(__file__).resolve().parent/'test_output'
output_dir.mkdir(exist_ok=True)
assert window.grab().save(str(output_dir/'pcui_smoke.png'))
window.close()
from ui_designer import MainWindow
designer=MainWindow()
designer.on_serial_loopback()
assert isinstance(designer._serial_window,LoopbackWindow)
designer._serial_window.close()
designer.close()
print('PCUI_GUI_PASS local-edit isolation, confirmed scene, disconnect clearing, designer toolbar')

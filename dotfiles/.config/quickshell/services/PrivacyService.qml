import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool isWebcamActive: false
    property bool isMicActive: false

    Process {
        id: hardwareMonitor
        running: true
        command: [
            "python3", "-u", "-c",
            "import subprocess, json, sys, time\n" +
            "browsers = {'firefox', 'chrome', 'chromium', 'brave', 'thorium', 'electron'}\n" +
            "while True:\n" +
            "  w = 0\n" +
            "  try:\n" +
            "    r = subprocess.run('fuser /dev/video* 2>/dev/null | grep -q .', shell=True)\n" +
            "    if r.returncode == 0: w = 1\n" +
            "  except: pass\n" +
            "  m = 0\n" +
            "  try:\n" +
            "    out = subprocess.check_output(['pactl', 'list', 'source-outputs'], stderr=subprocess.DEVNULL, text=True)\n" +
            "    for block in out.split('\\n\\n'):\n" +
            "      block = block.strip()\n" +
            "      if not block: continue\n" +
            "      if 'Corked: no' not in block: continue\n" +
            "      if '.monitor' in block.split('Source:')[-1].split('\\n')[0] if 'Source:' in block else '': continue\n" +
            "      app_lines = [l for l in block.split('\\n') if 'application.process.binary' in l]\n" +
            "      if not app_lines:\n" +
            "        m = 1\n" +
            "        break\n" +
            "      app = app_lines[0].split('=')[-1].strip().strip('\"').lower()\n" +
            "      if app not in browsers:\n" +
            "        m = 1\n" +
            "        break\n" +
            "  except: pass\n" +
            "  print(f'{w},{m}', flush=True)\n" +
            "  time.sleep(2)\n"
        ]
        stdout: SplitParser {
            onRead: (data) => {
                var parts = data.trim().split(",");
                if (parts.length === 2) {
                    root.isWebcamActive = (parts[0] === "1");
                    root.isMicActive = (parts[1] === "1");
                }
            }
        }
    }
}

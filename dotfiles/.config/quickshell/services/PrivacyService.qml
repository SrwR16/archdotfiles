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
        command: ["python3", "-u", "-c", "import subprocess, time\n" + "def source_map():\n" + "    m = {}\n" + "    try:\n" + "        out = subprocess.check_output(['pactl', 'list', 'sources'], stderr=subprocess.DEVNULL, text=True)\n" + "        cur = None; pending = False\n" + "        for line in out.splitlines():\n" + "            s = line.strip()\n" + "            if s.startswith('Source #'):\n" + "                cur = int(s.split('#')[1]); pending = True\n" + "            elif pending and s.startswith('Name:'):\n" + "                m[cur] = s.split(':', 1)[1].strip(); pending = False\n" + "    except Exception:\n" + "        pass\n" + "    return m\n" + "while True:\n" + "  w = 0\n" + "  try:\n" + "    if subprocess.run('fuser /dev/video* 2>/dev/null | grep -q .', shell=True).returncode == 0: w = 1\n" + "  except: pass\n" + "  m = 0\n" + "  try:\n" + "    srcs = source_map()\n" + "    out = subprocess.check_output(['pactl', 'list', 'source-outputs'], stderr=subprocess.DEVNULL, text=True)\n" + "    for block in out.split('\\n\\n'):\n" + "      block = block.strip()\n" + "      if not block: continue\n" + "      if 'Corked: no' not in block: continue\n" + "      sid = None\n" + "      if 'Source:' in block:\n" + "        tok = block.split('Source:')[-1].split('\\n')[0].strip()\n" + "        try: sid = int(tok.lstrip('#'))\n" + "        except ValueError:\n" + "          for k, v in srcs.items():\n" + "            if v == tok: sid = k\n" + "      name = srcs.get(sid, '')\n" + "      monitor = name.endswith('.monitor')\n" + "      real_input = (sid in srcs) and (not monitor)\n" + "      app = ''\n" + "      for l in block.split('\\n'):\n" + "        if 'application.process.binary' in l:\n" + "          app = l.split('=', 1)[-1].strip().strip('\\\"'); break\n" + "      if real_input:\n" + "        m = 1; break\n" + "  except Exception as e:\n" + "    print(f'PRIVDBG err={e!r}', flush=True)\n" + "  print(f'{w},{m}', flush=True)\n" + "  time.sleep(2)\n"]

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

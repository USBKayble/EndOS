import sys
import os
import json
import logging
import argparse
from pathlib import Path

from PySide6.QtGui import QGuiApplication, QFont, QPalette, QColor
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QObject, Signal, Slot, Property, QUrl

from backend.executor import get_executor
from backend.installer import Installer

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger("EndOS-Installer")

class InstallerBackend(QObject):
    """Bridge between QML and Python Logic."""
    
    def __init__(self, dry_run=False):
        super().__init__()
        self._dry_run = dry_run
        self.executor = get_executor(dry_run)
        logger.info(f"Initialized Backend (Dry-Run: {dry_run})")

    @Slot(str, result=str)
    def readFile(self, path):
        """Reads a file and returns contents. Useful for loading extensive configs or licenses."""
        path = Path(path)
        if not path.exists():
            return ""
        try:
            return path.read_text()
        except Exception as e:
            logger.error(f"Failed to read file {path}: {e}")
            return ""
            
    # Flags
    @Property(bool, constant=True)
    def isDryRun(self):
        return self._dry_run

class ThemeManager(QObject):
    """Manages color themes, loading from system or defaults."""
    
    def __init__(self):
        super().__init__()
        self._colors = {}
        self.load_system_colors()

    def load_system_colors(self):
        # Try to load from the user's current session first (dev mode)
        # In the ISO, this might need to look in /etc/skel or similar if running as root without a session
        paths = [
            Path("/home/kaleb/.local/state/quickshell/user/generated/colors.json"), # DEV
            Path("/root/.local/state/quickshell/user/generated/colors.json"),       # ISO Root
            Path("/etc/endos/colors.json")                                          # Fallback
        ]
        
        for p in paths:
            if p.exists():
                try:
                    data = json.loads(p.read_text())
                    # Prefer dark scheme
                    self._colors = data
                    logger.info(f"Loaded theme from {p}")
                    return
                except Exception as e:
                    logger.error(f"Failed to parse theme {p}: {e}")
        
        # Fallback defaults (Material Deep Purple)
        self._colors = {
            "primary": "#d0bcff",
            "onPrimary": "#381e72",
            "surface": "#141218",
            "onSurface": "#e6e1e5",
            "on_surface": "#e6e1e5",
            "on_surface_variant": "#938f99",
            "background": "#141218",
            "outline": "#938f99",
            "surfaceContainer": "#211f26",
            "surface_container": "#211f26",
            "surface_container_high": "#2b2930"
        }
        logger.warning("Using fallback theme")

    @Slot(str, result=str)
    def color(self, name):
        val = self._colors.get(name)
        if not val:
            logger.warning(f"Request for missing color: {name}")
            return "#FF00FF"
        return val

def main():
    parser = argparse.ArgumentParser(description="EndOS Graphical Installer")
    parser.add_argument("--dry-run", action="store_true", help="Simulate installation without making changes")
    args, qt_args = parser.parse_known_args()

    # Force Basic style and ignore user config
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
    os.environ["QT_QUICK_CONTROLS_CONF"] = "/dev/null"
    
    from PySide6.QtQuickControls2 import QQuickStyle
    QQuickStyle.setStyle("Basic")

    app = QGuiApplication(sys.argv)
    
    # Set default app font to Google Sans Flex
    font = QFont("Google Sans Flex")
    font.setPixelSize(14)
    font.setStyleHint(QFont.SansSerif)
    app.setFont(font)
    
    logger.info(f"App Font set to: {font.family()}")
    
    # Force Dark Palette for fallback
    palette = QPalette()
    palette.setColor(QPalette.Window, QColor("#141314"))
    palette.setColor(QPalette.WindowText, QColor("#e7e1e3"))
    palette.setColor(QPalette.Base, QColor("#141314"))
    palette.setColor(QPalette.AlternateBase, QColor("#1d1b1c"))
    palette.setColor(QPalette.ToolTipBase, QColor("#e7e1e3"))
    palette.setColor(QPalette.ToolTipText, QColor("#e7e1e3"))
    palette.setColor(QPalette.Text, QColor("#e7e1e3"))
    palette.setColor(QPalette.Button, QColor("#1d1b1c"))
    palette.setColor(QPalette.ButtonText, QColor("#e7e1e3"))
    palette.setColor(QPalette.BrightText, QColor("#ffffff"))
    palette.setColor(QPalette.Link, QColor("#d1c2d2"))
    palette.setColor(QPalette.Highlight, QColor("#d1c2d2"))
    palette.setColor(QPalette.HighlightedText, QColor("#141314"))
    app.setPalette(palette)

    engine = QQmlApplicationEngine()

    # Backend
    backend = InstallerBackend(dry_run=args.dry_run)
    backend.setParent(app)
    
    installer = Installer(dry_run=args.dry_run)
    installer.setParent(app)
    
    theme = ThemeManager()
    theme.setParent(app)

    # Expose to QML
    engine.rootContext().setContextProperty("Backend", backend)
    engine.rootContext().setContextProperty("Installer", installer)
    engine.rootContext().setContextProperty("ThemeBridge", theme)

    # Load UI
    qml_file = Path(__file__).parent / "ui/Main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        sys.exit(-1)

    sys.exit(app.exec())

if __name__ == "__main__":
    main()

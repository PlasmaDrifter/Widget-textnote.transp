# Transparent Text Note Widget

[![KDE Plasma 6](https://img.shields.io/badge/KDE_Plasma-6.0+-3152A0?style=for-the-badge&logo=kde&logoColor=white)](https://kde.org/plasma-desktop/)
[![QML](https://img.shields.io/badge/UI-QML%2FQt6-41CD52?style=for-the-badge&logo=qt&logoColor=white)](https://doc.qt.io/qt-6/qtqml-index.html)
[![Category](https://img.shields.io/badge/Notes%20%26%20Tasks-FFCC00?style=for-the-badge&logo=note&logoColor=white)](https://github.com/PlasmaDrifter)
[![License](https://img.shields.io/badge/License-GPL-2.0+-blue.svg?style=for-the-badge)](LICENSE)

A transparent sticky note widget for KDE Plasma 6 that blends seamlessly into any wallpaper.

---

## Previews

![Transparent Text Note Widget Preview](desktop-1.png)

---

## Features

- **Transparent**: background with zero card borders
- **Rich**: text formatting support
- **Auto-saving**: notes across system reboots
- **Custom**: font size and text color configuration

## Requirements

- **Environment**: KDE Plasma 6.0 or higher
- **Framework**: Qt6 QML / Plasma Applet API

## Installation

### Option 1: Git Clone (Recommended)
```bash
mkdir -p ~/.local/share/plasma/plasmoids/
git clone https://github.com/PlasmaDrifter/Widget-textnote.transp.git ~/.local/share/plasma/plasmoids/local.widget.textnote.transp
```

### Option 2: Plasma Package Installer
```bash
kpackagetool6 -i ~/.local/share/plasma/plasmoids/local.widget.textnote.transp
```

Then right-click your desktop or panel $\rightarrow$ **Add Widgets...** and search for the widget name.

## Credits & License

- **Author / Maintainer**: PlasmaDrifter
- **License**: Licensed under the [GPL-2.0+](LICENSE).

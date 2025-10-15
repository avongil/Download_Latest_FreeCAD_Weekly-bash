# Download_Latest_FreeCAD_Weekly-bash

Downloads the latest FreeCAD weekly (X86) to your AppImage folder then updates your link so desktop entry still works.
Tested on Arch Linux with XFCE, but it should work with all distros. Folders are customizable at the top.

edit these if needed: 

~~~
# Configuration
INSTALL_DIR="$HOME/.local/share/applications/AppImages"
DESKTOP_FILE="$HOME/.local/share/applications/freecad-weekly.desktop"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
RELEASES_URL="https://github.com/FreeCAD/FreeCAD/releases"
~~~

You could run this script automatically every Monday and always be up to date on the bleeding edge of FreeCAD!
\

\
To all the FreeCAD developers and contributers, thank you for all your hard work. FreeCAD V1.1 is truly world class CAD software.

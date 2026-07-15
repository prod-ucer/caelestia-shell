pragma ComponentBehavior: Bound

import Quickshell
import qs.components.misc
import qs.services

Scope {
    CustomShortcut {
        name: "clipboard"
        description: "Toggle clipboard history"
        onPressed: ShellState.toggleClipboard()
    }
}

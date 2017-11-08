# Tcl package index file, version 1.1
# This file is generated by the "pkg_mkIndex -load Tix" command
# and sourced either when an application starts up or
# by a "package unknown" script.  It invokes the
# "package ifneeded" command to set up package-related
# information so that packages will be loaded automatically
# in response to "package require" commands.  When this
# script is sourced, the variable $dir must contain the
# full path name of this file's directory.

package ifneeded qtk 1.0 [list source [file join $dir themes.tcl]]\n[list source [file join $dir qwidgets.tcl]]\n[list source [file join $dir layout.tcl]]\n[list source [file join $dir property_list.tcl]]\n[list source [file join $dir tk-utils.tcl]]\n[list source [file join $dir tcl-utils.tcl]]\n[list source [file join $dir fix-key-bindings.tcl]]\n[list source [file join $dir show-widget-doc.tcl]]\n[list source [file join $dir show-menu-doc.tcl]]\n[list source [file join $dir group-control.tcl]]\n[list source [file join $dir composite-widgets.tcl]]\n[list source [file join $dir grips.tcl]]\n[list source [file join $dir group-iconification.tcl]]
package ifneeded tile::theme::freedius 1.0 [list source [file join $dir themes.tcl]]
package ifneeded tixDirBrowse 1.0 [list source [file join $dir tix-dir-browse.tcl]]
package ifneeded ttkDirBrowse 1.0 [list source [file join $dir ttk-dir-browse.tcl]]

python
import os
import sys
sys.path.append('/home/rendell/.config/gdb/python')
end

add-auto-load-safe-path "/home/rendell/.config/gdb/auto-load"
add-auto-load-scripts-directory "/home/rendell/.config/gdb/auto-load"
# Uncomment if you have trouble getting auto-load working
set debug auto-load on

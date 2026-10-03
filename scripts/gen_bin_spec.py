#!/usr/bin/env python3

import os
import os.path


files = os.scandir('./')
bin_files = []
for file in files:
    file_name = file.path
    if file_name.endswith('.bin') or file_name.endswith('.clm_blob'):
        bin_files.append(file_name)


ada_pkg_str = "package bin_sizes is \n"

for f in bin_files:
    bin_name = f.strip('.bin').strip('/')
    ada_pkg_str += f"bin_{bin_name} : constant Integer := {os.path.getsize(f)}; \n"

ada_pkg_str += "rom_addr : constant Integer := 16#101c0000#;\n"
ada_pkg_str += "end bin_sizes;\n"

ada_spec = open('bin_sizes.ads', "w")
ada_spec.writelines(ada_pkg_str)
ada_spec.close()


    







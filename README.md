# BuildMétéo

[Click here](./blob/master/cao2017icsme.pdf) to read our paper in ICSME'17.

## Preparation

Before running [BuildMeteo.rb](./blob/master/BuildMeteo.rb), you should:

  1. If you wish to estimate the build duration for VTK, run `git clone https://gitlab.kitware.com/vtk/vtk.git`; otherwise, for GLib, run `git clone https://github.com/GNOME/glib`
  2. Download [MAKAO](http://mcis.polymtl.ca/makao.html)
  3. Move `build_files.txt` from `./files_*` to their corresponding source repository
  4. Create a new directory `build_dir` in the source repository
  5. Change directory to `build_dir` and run `cmake ..` to configure the source repository
  6. Run `$MAKAO/parsing/bin/makewrapper.sh all 2&> trace.txt` and `$MAKAO/parsing/bin/generate_makao_graph.pl -in trace.txt -out trace.gdf -format gdf`
  7. In `BuildMeteo.rb`, change both `SRCE_DIR` to the directory of the project you desire to test upon.

Once you finish running `BuildMeteo.rb`, there will be 2 csv file outputs, including:

  1. `commit_predict.csv` - predicted build duration for each commit
  2. `real_time.csv` - real build duration for each commit
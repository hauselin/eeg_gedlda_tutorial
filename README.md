# Short introduction to multivariate EEG analysis with linear discriminant analysis via generalized eigendecomposition

For intro slides, see `EEG_GED.pdf`

To begin  MATLAB tutorial, simulations, and analyses, open `simulations.m`

This MATLAB script simulates different sine waves at different sources/dipoles, mixes their activity via volume conduction, and performs linear discriminant analysis via generalized eigendecomposition on the scalp EEG data (sources mixed) to recover the simulated data.

Helper functions called by `simulations.m`: `dipole_project.m`, `filterFGx.m`, `topoplotIndie.m`

`emptyEEG.mat` contains two structures: `EEG` (empty EEGLAB structure for storing EEG data) and `lf` (leadfield matrix for projecting dipole activity to 64 channels)



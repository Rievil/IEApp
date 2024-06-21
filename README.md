![](https://github.com/Rievil/IEApp/blob/main/Ilustration/App_window.png)
# Impact-Echo application for microphone measruemnts
[![DOI](https://zenodo.org/badge/768488337.svg)](https://zenodo.org/doi/10.5281/zenodo.12204655)
Matlab aplication for Impact-Echo measurements and data storage. It uses a DirectSound driver for connection to any type of microphone or sound card. The IEApp requires these toolboxes:

- data_acq_toolbox
- matlab
- signal_toolbox

> [!IMPORTANT]
> To connect to sound card you will also need to install [Data Acquisition Toolbox Support Package for Windows Sound Cards](https://www.mathworks.com/matlabcentral/fileexchange/45171-data-acquisition-toolbox-support-package-for-windows-sound-cards).

# Usage
The app allows the user to pick the input microphone. There is possibility to set treshold, length of signals, pre-trigger time, sampling frequency. The app also allows you to design a group of descriptive variables, which allows to label signals for the purpose of the designed experiment. The signals and descriptive variables are stored in two tables, which are exported. The app allows to create templates of descriptive variables and use it for similar type of experiments. 

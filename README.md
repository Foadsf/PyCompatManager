# PyCompatManager

PyCompatManager is a PowerShell script designed to manage package installations for legacy Python versions, ensuring compatibility with the current Python environment. It interfaces with the Python Package Index (PyPI) to fetch the latest compatible release of a specified package, considering the installed Python version.

## Features

- Determines the currently installed Python version, focusing on major and minor version numbers.
- Fetches package data from PyPI using the specified package name.
- Parses the JSON response to identify the latest release compatible with the current Python environment.
- Outputs details of the compatible release or indicates if none is found.

## Usage

To use PyCompatManager, execute the script in PowerShell, passing the package name as an argument:

```powershell
.\PyCompatManager.ps1 -PackageName <your-package-name>
```

Ensure PowerShell has the necessary permissions to execute scripts and network access to communicate with the PyPI API.

## Requirements

- PowerShell 5.0 or higher
- Internet connection to access the PyPI API

## Contributing

Contributions to PyCompatManager are welcome! Please feel free to fork the repository, make your changes, and submit a pull request.

## License

PyCompatManager is released under the [GNU General Public License v3.0 (GPL-3.0)](https://www.gnu.org/licenses/gpl-3.0.en.html). This license allows for free use, modification, and distribution under the condition that enhancements or modifications are also bound by the same GPL-3.0 terms.

## Acknowledgments

Thanks to the Python community and the developers of the tools and libraries that make Python package management a robust and flexible endeavor.

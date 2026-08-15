# GitHub Actions Importer custom runner mappings for legacy Azure hosted images.
# These mappings intentionally modernize retired Azure DevOps image labels.

runner "ubuntu-16.04", "ubuntu-latest"
runner "macos-10.14", "macos-latest"
runner "vs2017-win2016", "windows-latest"
runner :default, "ubuntu-latest"

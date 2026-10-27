# aRTF Clothes evaluation subset

Source: https://doi.org/10.5281/zenodo.10875542

Authors: Thomas Lips, Victor-Louis De Gusseme, Francis wyffels.
Paper: *Learning Keypoints for Robotic Cloth Manipulation using Synthetic Data* (2024), https://arxiv.org/abs/2401.01734

Dataset license: CC BY 4.0, https://creativecommons.org/licenses/by/4.0/
Publisher's license statement: https://github.com/tlpss/aRTF-Clothes-dataset

These 16 unmodified PNGs come from the publisher's resized-paper-splits archive, test partition. Selection is the lexicographically first filename in each of eight scenes for each of tshirts and shorts. The manifest retains source paths and original keypoints; segmentation boundaries are subsampled to approximately 80 vertices for a coarse grid IoU benchmark. This is an exploratory development subset, not a held-out accuracy claim after algorithm changes. No training has been performed on these images.

There are no calibration cards or tape-measured garment dimensions in this subset. It evaluates garment localization only, not centimeter accuracy. The test bundle contains these files; the shipping app does not.

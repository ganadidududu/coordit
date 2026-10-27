# Cardless measurement third-party notices

No new third-party model weights or dataset archives are distributed in the app or Git repository.

aRTF Clothes dataset — Thomas Lips, Victor-Louis De Gusseme and Francis wyffels, Ghent University. [Original deposit](https://zenodo.org/records/14501499), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Learning Keypoints for Robotic Cloth Manipulation using Synthetic Data (2024). Dataset conversions/resizing are modifications. Existing evaluation fixtures retain their own `CameraDataset/ATTRIBUTION.md`.

ARKit/Vision are Apple platform frameworks. Android ARCore is subject to [Google APIs terms](https://developers.google.com/ar/develop/terms). SDK/sample code licensing and service terms are separate. Ruler was inspected as a reference (MIT); no Ruler source is copied.

Python dependencies and Android SDK dependencies retain their upstream notices. This file covers additions for this project, not a replacement for existing application dependency notices. See DATASET_LICENSES.md and MODEL_LICENSES.md for quarantine decisions.

Pinned Python package metadata was inspected locally: torch 2.9.1 BSD-3-Clause; numpy 2.5.4 BSD/0BSD/MIT/Zlib/CC0 components; Pillow 12.3.0 MIT-CMU; pydantic 2.14.1 MIT; FastAPI 0.162.0 MIT; uvicorn 0.54.0 BSD-3-Clause; httpx2 2.16.0 BSD-3-Clause. These permissive package grants are distinct from any model/data rights. Export-only ONNX dependencies and platform-specific transitive binaries require a complete deployment SBOM/notices audit before release. No NVIDIA/CUDA training or deployment occurred on this host.

# Bundled Real-ESRGAN

Run `python3 Scripts/bundle-upscaler.py` to materialize the ignored runtime binary and model weights. The script verifies the immutable official macOS 20220424 archive SHA-256 before extracting only the photographic x4plus model and helper, then thins the helper to arm64. Archive URL and checksum are also in manifest.json. Build packaging copies these resources, signs the helper, refreshes hashes, then signs the app. Processing is offline.

Source: https://github.com/xinntao/Real-ESRGAN (BSD-3-Clause)
Runner: https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan (MIT; see its retained full license)
Runtime dependencies are statically linked ncnn/MoltenVK and system macOS frameworks. License texts are in Licenses/. No Python interpreter, model downloader or package manager is distributed.

The selected x4plus model reconstructs RGB detail at 4×. Airu generates 2× by resampling the 4× neural result, scales alpha independently and restores the source RGB profile. SSIMULACRA2 scores cover output encoding relative to the enhanced raster, never reconstruction fidelity relative to the original photograph.

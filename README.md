# NMJ Auto-Analysis

ImageJ macro suite for automated measurement of neuromuscular junction (NMJ) morphology from confocal microscopy images.

## Overview

This toolkit provides a two-stage pipeline for NMJ analysis:
1. **Cropping**: Extract individual NMJs from multi-NMJ confocal images
2. **Quantitative Analysis**: Measure morphological features of cropped NMJs

## Quick Start

### Stage 1: Cropping NMJs

**For single images:**
```
1. Open your .lsm image in ImageJ
2. Run: Plugins > Macros > Run > NMJ_cropping.ijm (or press F10)
3. Select ROIs on the Z-projection
4. Cropped images saved to "cropped" subfolder
```

**For batch processing:**
```
1. Run: Plugins > Macros > Run > NMJ_cropping-folder-subStackSelect.ijm
2. Select folder containing .lsm files
3. For each image:
   - Select ROIs on Z-projection
   - Optionally choose substack range for each ROI
4. Cropped images saved to "cropped" subfolder
```

### Stage 2: Quantitative Measurement

**Full NMJ Analysis (terminal + endplate):**
```
1. Run: Plugins > Macros > Run > NMJ_quantitative_measures_v3.0.ijm (or press F10)
2. Choose whether to manually review thresholds
3. Select folder containing cropped .tif files (2-channel)
4. Results saved to "Analysis_[timestamp]" folder
```

**Endplate-Only Analysis (single channel):**
```
1. Run: Plugins > Macros > Run > NMJ_endplate_analysis.ijm (or press F11)
2. Choose whether to manually review thresholds
3. Select folder containing endplate .tif files (single-channel or first channel used)
4. Results saved to "Endplate_Analysis_[timestamp]" folder
```

Use endplate-only analysis when you have:
- Images with only pre-synaptic endplate staining
- Need only area and dispersion measurements
- Faster processing (skips terminal and overlap calculations)

## Measurements Performed

### Full NMJ Analysis (v3.0)

| Measurement | Description |
|------------|-------------|
| **termVol** | 3D volume of nerve terminal (μm³) |
| **endplateVol** | 3D volume of motor endplate (μm³) |
| **xRot, yRot** | Rotation angles for maximum en face projection |
| **overlap** | Synaptic overlap percentage (terminal/endplate) |
| **terminalArea** | En face area of terminal (μm²) |
| **endplateArea** | En face area of endplate (μm²) |
| **efDispRatio** | En face dispersion ratio (convex hull / stained area) |
| **frag** | Number of discrete endplate fragments |
| **fragvol** | Volume of each fragment (μm³) |

### Endplate-Only Analysis

| Measurement | Description |
|------------|-------------|
| **xRot, yRot** | Rotation angles for maximum en face projection |
| **endplateArea** | En face area of endplate (μm²) |
| **efDispRatio** | En face dispersion ratio (convex hull / stained area) |

## Requirements

### ImageJ/Fiji
- ImageJ 1.52+ or Fiji

### Required Plugins (included in repository)

Place these files in your ImageJ `plugins` folder:

**JAR files (root directory):**
- `loci_tools.jar` - Bio-Formats library for reading .lsm files
- `auto_threshold.jar` - Automatic thresholding algorithms
- `ij-plugins_toolkit.jar` - 3D image processing

**Plugin classes (Plugins for auto-measure macro/ directory):**
- `Object_Counter3D.class` - 3D object counting
- `NMJ_Convex_Hull.class` - Custom convex hull calculation
- `TransformJ_.jar` - 3D transformations and rotations
- `imagescience.jar` - Support library for TransformJ

### Installation

```bash
# Copy JAR files to ImageJ plugins folder
cp *.jar /path/to/ImageJ/plugins/

# Copy class files to ImageJ plugins folder
cp "Plugins for auto-measure macro"/* /path/to/ImageJ/plugins/

# Restart ImageJ
```

## File Organization

```
nmj-image-analysis/
├── NMJ_cropping.ijm                          # Single image cropping
├── NMJ_cropping-folder.ijm                   # Batch cropping (basic)
├── NMJ_cropping-folder-subStackSelect.ijm    # Batch cropping with substack selection ⭐
├── NMJ_quantitative_measures_v3.0.ijm        # Full NMJ analysis (terminal + endplate) ⭐
├── NMJ_endplate_analysis.ijm                 # Endplate-only analysis (single channel) ⭐
├── archive/                                   # Older versions (not for production use)
│   ├── NMJ_quantitative_measures_v2.6.ijm
│   ├── NMJ_quantitative_measures_v2.6.1.ijm
│   └── NMJ_quantitative_measures_v2.7.ijm
├── Plugins for auto-measure macro/           # Required plugin files
├── *.jar                                      # Required libraries
└── README.md

⭐ = Recommended for new analyses
```

## Workflow Example

**Typical analysis workflow:**

1. **Acquire images**: 2-color confocal stacks (.lsm format)
   - Channel 1: Motor endplate marker
   - Channel 2: Nerve terminal marker

2. **Crop individual NMJs**:
   ```
   Input:  raw_images/muscle_sample_001.lsm (contains 5 NMJs)
   Output: raw_images/cropped/muscle_sample_001-1.tif
           raw_images/cropped/muscle_sample_001-2.tif
           ...
           raw_images/cropped/muscle_sample_001-5.tif
   ```

3. **Quantitative analysis**:
   ```
   Input:  raw_images/cropped/*.tif
   Output: raw_images/cropped/Analysis_Jun-28-2019_1430/
           ├── TotalResults_Jun-28-2019_1430.csv       # Main results
           ├── BatchLog_Jun-28-2019_1430.txt           # Processing log
           ├── 3D Objects summary_Jun-28-2019_1430.txt # Fragment details
           ├── muscle_sample_001-1_overlap.jpg         # Overlap visualization
           ├── muscle_sample_001-1_enFaceDisp.jpg      # Dispersion visualization
           └── ...
   ```

4. **Analyze results**: Open `TotalResults_[timestamp].csv` in Excel/R/Python

## Troubleshooting

### "Plugin not found" errors
- Ensure all .jar and .class files are in the ImageJ plugins folder
- Restart ImageJ after adding plugins

### Threshold looks wrong
- v3.0 allows manual threshold adjustment - use this for difficult images
- Ensure image contrast is adequate (check raw data quality)

### "No objects found" error
- Image may be too dim or noisy
- Try adjusting threshold manually
- Check that channels are not swapped

### Macro runs very slowly
- Normal for large image stacks (rotation is computationally intensive)
- Batch mode is enabled by default to improve speed
- Processing 50 images may take 1-2 hours depending on image size

## Version History

### v3.0 (June 2019) - Current
- Added manual threshold review capability
- Improved error handling for edge cases
- Fixed division-by-zero errors
- Fixed hardcoded paths in cropping macros

### v2.7 (May 2019) - Archived
- Fixed rotation calculations
- Added en face area reporting
- CSV output format

See `archive/README.md` for details on older versions.

## Citation

If you use this software in your research, please cite:

Johnson AM, Ciucci MR, Connor NP. Vocal training mitigates age-related changes within the vocal mechanism in old rats. J Gerontol A Biol Sci Med Sci. 2013 Dec;68(12):1458-68. doi: 10.1093/gerona/glt044. Epub 2013 May 13. PMID: 23671289; PMCID: PMC3814239.

## Author

**Aaron Johnson**
- Developed for NMJ morphology analysis
- Last updated: June 2019 (v3.0)
- Code review and improvements: November 2025

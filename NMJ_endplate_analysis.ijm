///////////////////////////////////////////////////////////////////////////////

/**
 * This ImageJ macro automatically measures the endplate area and dispersion
 * from single-channel images containing only endplate staining.
 *
 * This is a simplified version of the full NMJ analysis macro for use when
 * only endplate measurements are needed.
 *
 * REQUIRES:
 *    NMJ_Convex_Hull.class (custom code)
 *
 * INPUT: a folder of single-channel .tiff documents containing endplate staining
 *
 * OUTPUT: CSV file with endplate area and dispersion ratio for each image
 *
 * @author Aaron Johnson
 *
 * Version 1.0
 * 12/10/2025
 * - Initial version for endplate-only analysis
 * - Measures endplate en face area and dispersion ratio
 * - Supports manual threshold review
 *
 */

///////////////////////////////////////////////////////////////////////////////
// CONFIGURATION CONSTANTS
///////////////////////////////////////////////////////////////////////////////

// Image processing parameters
var MEDIAN_FILTER_RADIUS = 2;           // Noise reduction filter size (pixels)
var BINARY_THRESHOLD_LOWER = 1;         // Lower threshold for binary images
var BINARY_THRESHOLD_UPPER = 255;       // Upper threshold for binary images

// 3D rotation parameters
var ROTATION_INCREMENT = 1;              // Degrees per rotation step
var ROTATION_TOTAL = 180;                // Total rotation angle to search

///////////////////////////////////////////////////////////////////////////////


macro "NMJ Endplate Analysis [f11]" {
//create a TimeStamp to record day and time analysis took place
  startTime = timeStamp();

//ask user if want to manually review thresholds
  Dialog.create("Manual threshold review?");
  Dialog.addCheckbox("Manually adjust ENDPLATE thresholds before analysis", true);
  Dialog.addMessage("If checkbox is deselected, autothresholding will be applied");
  Dialog.show();
  manualThreshold_endplate = Dialog.getCheckbox();

//select directory of .tiff images to process
  dir = getDirectory("Choose a directory of endplate images");
  dirlist = getFileList(dir);

//validate that directory contains .tif files
  tiffCount = 0;
  for(i=0; i<dirlist.length; i++) {
    if(endsWith(dirlist[i], "tif")) tiffCount++;
  }

  if(tiffCount == 0) {
    showMessage("Error", "No .tif files found in selected directory!\n\nPlease select a directory containing .tif images.");
    exit();
  }

//create text window to save the cumulative results
  totalResults = "TotalResults";
  run("Text Window...", "name="+totalResults+" width=40 height=20");

//create text window to save the titles of the images processed
  batchLog = "BatchLog";
  run("Text Window...", "name="+batchLog+" width=60 height=20");
  print("["+batchLog+"]", "Batch started: " + startTime + "\n");
  print("["+batchLog+"]", "Found " + tiffCount + " .tif files to process\n\n");

//print header for results
  print("["+totalResults+"]",
    "filename,"
    + "xRot," + "yRot,"
    + "endplateArea,"
    + "efDispRatio\n");

//create output directory to store results
  outputDir = dir + "Endplate_Analysis_" + startTime + File.separator;
  File.makeDirectory(outputDir);

  for(i=0; i<dirlist.length; i++) {
    String.resetBuffer;
    currfile = dir+dirlist[i];

    if(endsWith(currfile, "tif")) {
    //update progress bar and status message
      currentFileNum = 0;
      for(j=0; j<=i; j++) {
        if(endsWith(dirlist[j], "tif")) currentFileNum++;
      }
      showProgress(currentFileNum / tiffCount);
      showStatus("Processing file " + currentFileNum + " of " + tiffCount + ": " + dirlist[i]);

    //open image (single channel or take first channel if multi-channel)
      open(currfile);

      //if multi-channel, extract first channel
      if(nSlices > 1) {
        getDimensions(width, height, channels, slices, frames);
        if(channels > 1) {
          run("Split Channels");
          selectImage(1);
          //close other channels
          for(c=2; c<=channels; c++) {
            selectImage(c);
            close();
          }
          selectImage(1);
        }
      }

      endplate = getImageID();

    //add file name to string output
      filename = substring(getTitle(), 0, lastIndexOf(getTitle(), "."));

    //print name of file and current time to batchlog
      currTime = timeStamp();
      print("["+batchLog+"]", filename + "\t" + currTime + "\n");

    //add filename to output
      print("["+totalResults+"]", filename + ",");

/** THRESHOLDING AND CONVERTING TO BINARY **/

    //binarize endplate stack (threshold and remove noise)
      endplate = binarizeStack(endplate, manualThreshold_endplate, "ENDPLATE");

/** MEASUREMENTS **/

      setBatchMode(true);

    //calculate en face area and dispersion
    //function returns array: [xRot, yRot, endplateArea, efDispRatio]
      endplateResults = analyzeEndplate(endplate);

    //Add the results to total results file
      print("["+totalResults+"]",
        endplateResults[0] + "," + endplateResults[1] + ","
        + endplateResults[2] + "," + endplateResults[3] + "\n");

    //save images for troubleshooting
      selectImage(endplate);
      saveAs("tiff", outputDir + filename + "_endplate");

    //close open images
      while (nImages>0) {
        selectImage(nImages);
        close();
      }

    //close the results window if it exists
      if(isOpen("Results")) {
        selectWindow("Results");
        run("Close");
      }

      setBatchMode(false);
    } //end if(.tif document)

  } //end for loop through files in directory

//create a TimeStamp to record day and time analysis completed
  stopTime = timeStamp();
  print("["+batchLog+"]", "Batch completed: " + stopTime + "\n");

//save batch log
  if(isOpen("BatchLog")) {
    selectWindow("BatchLog");
    save(outputDir + "BatchLog_" + startTime + ".txt");
    run("Close");
  }

//save results
  if(isOpen("TotalResults")) {
    selectWindow("TotalResults");
    run("Text...", "save=[" + outputDir + "EndplateResults_" + startTime + ".csv]");
    run("Close");
  }

  showMessage("Macro Complete");
  setBatchMode(false);
} //end macro


/**
 * Function to analyze endplate and return en face area and dispersion.
 *
 * @param epStack The endplate image stack
 * @return Array containing [xRot, yRot, endplateArea, efDispRatio]
 */
function analyzeEndplate(epStack) {
//scale with linear transformation to make voxels square
  selectImage(epStack);
  getVoxelSize(vwidth, vheight, vdepth, vunit);
  zfactor = vdepth / vwidth;
  run("TransformJ Scale", "x-factor=1.0 y-factor=1.0 z-factor="+zfactor+" interpolation=linear");
  epScaled = getImageID();

//find maximum area in y-axis rotation
  yRot = findMaxRotationAngle(epScaled, "Y-Axis");

//rotate the image to the maximum area y-axis angle
  selectImage(epScaled);
  run("TransformJ Rotate", "z-angle=0.0 y-angle=" + yRot + " x-angle=0.0 interpolation=[nearest neighbor] background=0.0 adjust");
  epScaledYRot = getImageID();

//find maximum area in x-axis rotation
  xRot = findMaxRotationAngle(epScaledYRot, "X-Axis");

//rotate to the maximum area x-axis angle
  selectImage(epScaledYRot);
  run("TransformJ Rotate", "z-angle=0.0 y-angle=0 x-angle=" + xRot + " interpolation=[nearest neighbor] background=0.0 adjust");
  epScaledYXRot = getImageID();

//create z-proj of rotated endplate stack
  selectImage(epScaledYXRot);
  run("Z Project...", "  projection=[Max Intensity]");
  setThreshold(BINARY_THRESHOLD_LOWER, BINARY_THRESHOLD_UPPER);
  run("Convert to Mask", "  black");
  endplateZ = getImageID();

//measure area
  run("Clear Results");
  run("Set Measurements...", "area limit redirect=None decimal=2");
  run("Measure");
  endplateArea = getResult("Area");

//calculate dispersion ratio
  efDispRatio = calculateDispersion(endplateZ);

//save dispersion image
  selectImage(endplateZ);
  saveAs("Jpeg", outputDir + filename + "_enFaceDisp");

  return newArray(xRot, yRot, endplateArea, efDispRatio);
} //end analyzeEndplate function


/**
 * Function to calculate dispersion ratio using convex hull.
 *
 * @param image Binary z-projection image
 * @return Dispersion ratio (convex hull area / stained area)
 */
function calculateDispersion(image) {
  selectImage(image);

//set threshold and measure area of z-projection
  setThreshold(BINARY_THRESHOLD_LOWER, BINARY_THRESHOLD_UPPER);
  run("Set Measurements...", "area limit redirect=None decimal=2");
  run("Measure");
  stainedArea = getResult("Area", nResults-1);

//measure convex hull of z-projection
  run("Set Measurements...", "area redirect=None decimal=2");
  run("NMJ Convex Hull");
  run("Measure");
  dispArea = getResult("Area", nResults-1);

//calculate dispersion ratio
  if(stainedArea > 0) {
    dispenface = dispArea/stainedArea;
  } else {
    dispenface = 0;
    print("["+batchLog+"]", "WARNING: " + filename + " - stained area is 0, cannot calculate dispersion\n");
  }

  return dispenface;
}


/**
 * Function to find the rotation angle that produces maximum area projection.
 *
 * @param imageStack The ID of the image stack to rotate
 * @param axis The rotation axis ("X-Axis" or "Y-Axis")
 * @return The rotation angle (in degrees) that produces maximum area
 */
function findMaxRotationAngle(imageStack, axis) {
  selectImage(imageStack);
  getVoxelSize(vwidth, vheight, vdepth, vunit);

  //create 3D projection with rotation
  run("3D Project...", "projection=[Brightest Point] axis="+axis+" slice="+vdepth+
      " initial=0 total="+ROTATION_TOTAL+" rotation="+ROTATION_INCREMENT+
      " lower="+BINARY_THRESHOLD_LOWER+" upper="+BINARY_THRESHOLD_UPPER+
      " opacity=0 surface=0 interior=0");

  //find rotation angle with maximum area
  run("Clear Results");
  run("Set Measurements...", "area limit redirect=None decimal=2");
  maxArea = 0;
  rotation = 0;

  for(j=1; j<ROTATION_TOTAL; j++) {
    setSlice(j);
    setThreshold(BINARY_THRESHOLD_LOWER, BINARY_THRESHOLD_UPPER);
    run("Measure");
    if(getResult("Area") > maxArea) {
      rotation = j-1;
      maxArea = getResult("Area");
    }
  }

  //close the 3D projection (no longer needed)
  close();

  return rotation;
}


/**
 * Function to binarize a stack with optional manual threshold review.
 *
 * @param imageID The ID of the image to threshold
 * @param manualReview Whether to allow manual threshold adjustment
 * @param imageName Name of the image for user prompts (e.g., "ENDPLATE")
 * @return The ID of the binarized image
 */
function binarizeStack(imageID, manualReview, imageName) {
  selectImage(imageID);

  //autothreshold stack
  setAutoThreshold("Default dark stack");

  if(manualReview) {
    getThreshold(lower, upper);
    //take value from autothresholded stack and apply to new z-proj
    run("Z Project...", "projection=[Max Intensity]");
    setThreshold(lower, upper);
    run("In [+]");
    run("In [+]");
    tempZstack = getImageID();
    //ask user to adjust threshold if necessary
    waitForUser('Threshold','Adjust '+imageName+' threshold on z-stack if necessary, then click OK\nIf thresholding tool is not open, open it via Image > Adjust > Threshold');
    selectImage(tempZstack);
    getThreshold(lower, upper);
    close(tempZstack);
    //apply default or adjusted threshold
    selectImage(imageID);
    setThreshold(lower, upper);
  } //endif manualThreshold

  //convert to binary (mask)
  run("Convert to Mask", "method=Default background=Dark black");
  //smooth out noise with median filter (only 2D, runs on each slice)
  run("Median...", "radius="+MEDIAN_FILTER_RADIUS+" stack");

  //return the binarized image ID
  return getImageID();
}


/**
 * Function to create a string that contains the date and time.
 */
function timeStamp(){
  MonthNames = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
  getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
  TimeString = MonthNames[month];
  if (dayOfMonth<10) {TimeString = TimeString + "-0" + dayOfMonth + "-" + year + "_";}
    else TimeString = TimeString + "-" + dayOfMonth + "-" + year + "_";
  if (hour<10) {TimeString = TimeString + "0" + hour;}
    else TimeString = TimeString + hour;
  if (minute<10) {TimeString = TimeString + "0" + minute;}
    else TimeString = TimeString + minute;
  return TimeString;
}

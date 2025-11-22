///////////////////////////////////////////////////////////////////////////////

/**
 * This ImageJ macro automatically measures the volume of the nerve
 * terminal and motor endplate of an NMJ, as well as the synaptic overlap.
 * Synpatic overlap is measured by rotating the endplate image until the 
 * maximum area of the z-projection in both x and y is found.  The nerve 
 * terminal image is then rotated the same amount and the overlap between the
 * z-projections of both rotated images is measured.  The resulting 
 * measurements are copied to the system clipboard in the following 
 * tab-delimited field order:
 * filename termVol endplateVol convexVol
 * dispRatio xRot yRot overlap frag
 * 
 * REQUIRES: 
 *    Object_Counter3D.class (3D Objects Counter plugin): https://imagej.nih.gov/ij/plugins/track/objects.html
 *    NMJ_Convex_Hull.class (custom code)
 *    TransformJ_.jar: https://imagescience.org/meijering/software/transformj/
 *    imagescience.jar (support libraries for TransformJ)
 * 
 * INPUT: a folder of 2-color .tiff documents.  Each tiff should contain one NMJ
 * 
 * @author Aaron Johnson
 *
 * Version 3.0
 * 06/28/2019
 * - added option to manually review threshold
 *
 * Version 2.7
 * 05/24/2019
 * - fixed rotation in synaptic overlap and enfacedisp
 * - removed 3D dispersion ratio calculation
 * - added reporting of enface areas for endplate and terminal
 * - changed results output to .csv format 
 * 
 * Version 2.6.2
 * 05/09/2019
 * - cleaned up code for thresholding and filtering both terminal and endplate
 * 
 * Version 2.6.1
 * 03/07/2019
 * - trying to find the appropriate threshold
 * 
 * Version 2.6
 * 02/01/2019
 * - changed input to tiffs which had additional periods in name, requiring...
 * - changed "indexOf(getTitle(), "."));" to "lastIndexOf(getTitle(), "."));"
 * - updated code for Merge Channels
 * - updated 3D Objects Counter (now using Object_Counter3D.class) and set minimum particle size to 255 voxels (approximately 1 cubic micron)
 * 
 * Version 2.5
 * 06/12/2014
 * - Updating for UIUC
 * - change input file to hyperstack
 *
 * Version 2.4
 * 10/06/2011
 * - Fixed threshold not working for endplate. New endplate thresholding added:
 *   Median filter, stretch histogram, convert to 8-bit, then threshold at (10,255)
 *
 * Version 2.3
 * 10/04/2011
 * - Otsu was not working for endplate so went back to fixed threshold of (10, 4095)
 * - ADDED en face 2D dispersion measurement
 * 
 * Version 2.2
 * 10/02/2011
 * - removed minimum size of 3D Object size filter in response to "No object found" error.
 *   Hoping filtering will reduce number of fragments found (had over 1500 in first try with no min)
 * - went back to Otsu for endplate thresholding - TODO: check if dim staining is picked up
 *
 * Version 2.1
 * 09/27/2011
 * - changed threshold method by first doing a median filter, then use
 *   set threshold at fixed level based on median max intensity of all stack histograms,
 *   then 3D erode and dilate to remove noise
 * - increased 3D Object size filter to minimum of 575 voxels (approximately 
 *   1 cubic micron)
 *
 * Version 2.0
 * 08/11/2011
 * - Completely revamped 
 * - Changed input image requirement to 2-color Nikon .nd2 images
 * - Removed qualitative measures
 * - Added synaptic overlap and endplate fragmentation
 * - Incorporated stack volume from previous NMJ_Volume plugin (that plugin is no longer needed)
 * 
 * 
 */


macro "NMJ Analysis [f10]" {
//create a TimeStamp to record day and time analysis took place
  startTime = timeStamp();

//ask user if want to manually review thresholds
  Dialog.create("Manual threshold review?");
  Dialog.addCheckbox("Manually adjust ENDPLATE thresholds before analysis", true);
  Dialog.addCheckbox("Manually adjust TERMINAL thresholds before analysis", true);
  Dialog.addMessage("If checkbox is deselected, autothresholding will be applied");
  Dialog.show();
  manualThreshold_endplate = Dialog.getCheckbox();
  manualThreshold_terminal = Dialog.getCheckbox();
  

//select directory of .tiff images to process
  dir = getDirectory("Choose a directory of terminal and endplate images");
  dirlist = getFileList(dir);

//create text window to save the cumulative results 
  totalResults = "TotalResults";
  run("Text Window...", "name="+totalResults+" width=40 height=20");

//create text window to save the titles of the images processed
  batchLog = "BatchLog";
  run("Text Window...", "name="+batchLog+" width=60 height=20");
  print("["+batchLog+"]", "Batch started: " + startTime + "\n");

//print header for results
  print("["+totalResults+"]", 
    "filename," 
    + "termVol," + "endplateVol," 
    + "xRot," + "yRot," + "overlap," 
    + "terminalArea," + "endplateArea,"
    + "efDispRatio," 
    + "frag,"+ "fragvol\n");

//create output directory to store results (and montage images??)
  outputDir = dir + "Analysis_" + startTime + File.separator;
  File.makeDirectory(outputDir);
  

  for(i=0; i<dirlist.length; i++) {
    String.resetBuffer;
    currfile = dir+dirlist[i];

    if(endsWith(currfile, "tif")) {
    //open hyperstack tiff image and split
      open(currfile);
	  run("Split Channels");

      selectImage(1);
      endplate = getImageID();
      selectImage(2);
      terminal = getImageID();

    //add file name to string output
      filename = substring(getTitle(), 0, lastIndexOf(getTitle(), "."));

    //print name of file and current time to batchlog to track which images were processed
      currTime = timeStamp();
      print("["+batchLog+"]", filename + "\t" + currTime + "\n");

    //add filename to output
	  print("["+totalResults+"]", filename + ",");

/** THRESHOLDING AND CONVERTING TO BINARY **/

    //binarize terminal stack (threshold and remove noise)
	  selectImage(terminal);
	  //autothreshold stack
	    setAutoThreshold("Default dark stack");

	  if(manualThreshold_terminal) {
	    getThreshold(lower, upper);
	  //take value from autothresholded stack and apply to new z-proj
	    run("Z Project...", "projection=[Max Intensity]");
	    setThreshold(lower, upper);
		run("In [+]");
		run("In [+]");
		tempZstack = getImageID();
	  //ask user to adjust threshold if necessary
	    waitForUser('Threshold','Adjust threshold on z-stack if necessary, then click OK\nIf thresholding tool is not open, press ctrl+shift+t');
		selectImage(tempZstack);
	    getThreshold(lower, upper);
		close(tempZstack);
	  //apply default or adjusted threshold
	    selectImage(terminal); 
	    setThreshold(lower, upper);
	  } //endif manualThreshold

	  //convert to binary (mask)
	  run("Convert to Mask", "method=Default background=Dark black");
	  //smooth out noise with median filter (only 2D, runs on each slice)
	  run("Median...", "radius=2 stack"); 
	  //update terminal variable to new thresholded image
	  terminal = getImageID();
	  
    //binarize endplate stack (threshold and remove noise)
	  selectImage(endplate);
	  //autothreshold stack
	    setAutoThreshold("Default dark stack");

	  if(manualThreshold_endplate) {
	    getThreshold(lower, upper);
	  //take value from autothresholded stack and apply to new z-proj
	    run("Z Project...", "projection=[Max Intensity]");
	    setThreshold(lower, upper);
		run("In [+]");
		run("In [+]");
		tempZstack = getImageID();
	  //ask user to adjust threshold if necessary
	    waitForUser('Threshold','Adjust threshold on z-stack if necessary, then click OK');
		selectImage(tempZstack);
	    getThreshold(lower, upper);
		close(tempZstack);
	  //apply default or adjusted threshold
	    selectImage(endplate); 
	    setThreshold(lower, upper);
	  } //endif manualThreshold

	  //convert to binary (mask)
 	  run("Convert to Mask", "method=Default background=Dark black");
       //smooth out noise with median filter (only 2D, runs on each slice)
      run("Median...", "radius=2 stack");
	  //update endplate variable to new thresholded image
	  endplate = getImageID();


/** MEASUREMENTS START; DO NOT CHANGE CODE BELOW **/
	  
	//OPTIONAL: decrease the run time by not displaying new images (may cause problem with some commands)
	  setBatchMode(true); 

    //measure volumes
      termVol = stackVolume(terminal);
      endVol = stackVolume(endplate);
//NEXT LINE IS FOR DEBUGGING
//print("["+batchLog+"]", "stackVolume complete" + "\n");

    //calculate synaptic overlap
    //function synapticOverlap returns an array that contains 
    //the synaptic overlap percentage, 
    //the x and y rotation angles, and
    //the en face terminal and endplate areas
      synOverlap = synapticOverlap(endplate, terminal);
//NEXT LINE IS FOR DEBUGGING
//print("["+batchLog+"]", "synOverlap complete" + "\n");
	  
	//calculate 2D dispersion of rotated en face endplate (returned as 4th element of the synOverlap array)
	  efDispRatio = enFaceDispersion(synOverlap[3]);
//NEXT LINE IS FOR DEBUGGING
//print("["+batchLog+"]", "efDispRatio complete" + "\n");

    //calculate endplate fragmentation (# of discrete motor endplate clusters) and the volume of each of those fragments
      endplateFrag = fragmentation(endplate);
	  fragNum = endplateFrag[0];
//NEXT LINE IS FOR DEBUGGING
//print("["+batchLog+"]", "endplateFrag complete" + "\n");

    //Add the results to total results file
      print("["+totalResults+"]",
        d2s(termVol, 0) + "," + d2s(endVol, 0) + ","  
		+ synOverlap[0] + "," + synOverlap[1] + "," 
		+ synOverlap[2] + "," + synOverlap[4] + ","
		+ synOverlap[5] + "," + efDispRatio + "," + fragNum);
      for (k=1; k<lengthOf(endplateFrag); k++) {
	    print("["+totalResults+"]", "," + endplateFrag[k]);
	  }
      Array.print(endplateFrag); 
	  print("["+totalResults+"]", "\n");
	  
//save images for troubleshooting
	selectImage(terminal);
    saveAs("tiff", outputDir + filename + "_terminal");
	selectImage(endplate);
    saveAs("tiff", outputDir + filename + "_endplate");

    //close open images
      while (nImages>0) {
        selectImage(nImages);
        close();
      }

    //close the results window
      selectWindow("Results");
      run("Close");

	  setBatchMode(false);
    } //end if(.tif document)

  } //end for loop through files in directory

//create a TimeStamp to record day and time analysis completed
  stopTime = timeStamp();
  print("["+batchLog+"]", "Batch completed: " + stopTime + "\n");

//save batch log
  selectWindow("BatchLog");
  save(outputDir + "BatchLog_" + startTime + ".txt");
  run("Close");

//save results
  selectWindow("Log");
  save(outputDir + "3D Objects summary_" + startTime + ".txt");
  run("Close");
  
  selectWindow("TotalResults");
  run("Text...", "save=[" + outputDir + "TotalResults_" + startTime + ".csv]");
  run("Close");

  showMessage("Macro Complete");
  setBatchMode(false); 
} //end macro


/**
 * Function to measure the volume of a binary stack.
 */
function stackVolume(image) {
    selectImage(image);
    getVoxelSize(vwidth, vheight, vdepth, vunit);
    run("Clear Results");
    run("Set Measurements...", "area limit decimal=2");
    runningTotal=0;
  //measure area of each slice and calculate running total 
    for (j=1; j<=nSlices; j++) {
      setSlice(j);
      setThreshold(1, 255);
      run("Measure");
      runningTotal=runningTotal + getResult("Area", nResults-1);
    }
  //calculate volume by multiplying total area by voxel depth
    volume = runningTotal * vdepth; 
    return volume;
}



/**
 * Function to measure the amount of overlap of the maximum projections of two stacks.
 * Rotates stack 1 to find the maximum area, rotates stack 2 by the same amount.
 */

function synapticOverlap(epStack, termStack) {
//reslice with linear transformation (same method as 3D projection) to make voxels square (so we don't need to interpolate in 3D projection)

  selectImage(epStack);
  getVoxelSize(vwidth, vheight, vdepth, vunit);
  zfactor = vdepth / vwidth;
  run("TransformJ Scale", "x-factor=1.0 y-factor=1.0 z-factor="+zfactor+" interpolation=linear");
  epScaled = getImageID();

//find maximum area in y-axis rotation
//rotate the resliced endplate stack; create 180 degree 3D projection with 1 degree rotations on y-axis - no need for interpolation b/c distance between stacks is now less than 1 pixel
//commenting out for troubleshooting  selectImage(epScaled);
  selectImage(epScaled);
  getVoxelSize(vwidth, vheight, vdepth, vunit);
  run("3D Project...", "projection=[Brightest Point] axis=Y-Axis slice="+vdepth+" initial=0 total=180 rotation=1 lower=1 upper=255 opacity=0 surface=0 interior=0");
//convert 3D projection to binary
//  setThreshold(1, 255);
//  run("Convert to Mask", "  black");
//find y rotation angle
  run("Clear Results");
  run("Set Measurements...", "area limit redirect=None decimal=2");
  maxAreaY = 0;
  yRot = 0;
  for(j=1; j<180; j++) {
    setSlice(j);
    setThreshold(1, 255);
	run("Measure");
    if(getResult("Area") > maxAreaY) {
      yRot = j-1;
      maxAreaY = getResult("Area");
    }
  } //end rotation for loop


//NEXT LINE IS FOR DEBUGGING
//for debugging save results
//    selectWindow("Results");
//    saveAs("text", outputDir + filename + "maxEPareaY");


//after maximum area is found, use TransformJ to rotate the resliced image to the maximum area y-axis angle
  selectImage(epScaled);
  run("TransformJ Rotate", "z-angle=0.0 y-angle=" + yRot + " x-angle=0.0 interpolation=[nearest neighbor] background=0.0 adjust");
  epScaledYRot = getImageID();
  
//find maximum area in x-axis rotation
//from newly rotated stack (epScaledYRot) create 180 degree 3D projection with 1 degree rotations on x-axis, with interpolation
  getVoxelSize(vwidth, vheight, vdepth, vunit);
  run("3D Project...", "projection=[Brightest Point] axis=X-Axis slice="+vdepth+" initial=0 total=180 rotation=1 lower=1 upper=255 opacity=0 surface=0 interior=0");
//convert 3D projection to binary
//  setThreshold(1, 255);
//  run("Convert to Mask", "  black");
//rotate find x rotation angle
  maxAreaX = 0;
  xRot = 0;
  run("Clear Results");
  run("Set Measurements...", "area mean limit redirect=None decimal=3");
  for(j=1; j<180; j++) {
    setSlice(j);
    setThreshold(1, 255);  
	run("Measure");
    if(getResult("Area") > maxAreaX) {
      xRot = j-1;
      maxAreaX = getResult("Area");
    }
  } //end rotation for loop

  
//NEXT LINE IS FOR DEBUGGING
//for debugging save results
//    selectWindow("Results");
//    saveAs("text", outputDir + filename + "maxEPareaX");


//when the maximum area is found, use TransformJ to rotate epScaledYRot to the maximum area x-axis angle
  selectImage(epScaledYRot);
  run("TransformJ Rotate", "z-angle=0.0 y-angle=0 x-angle=" + xRot + " interpolation=[nearest neighbor] background=0.0 adjust");
  epScaledYXRot = getImageID();
  
  
//NEXT LINE IS FOR DEBUGGING
//save rotated image
//saveAs("tiff", outputDir + filename + "_rotatedEndplate");

  
  //create z-proj of rotated endplate stack
  selectImage(epScaledYXRot);
  run("Z Project...", "  projection=[Max Intensity]");
  setThreshold(1, 255);
  run("Convert to Mask", "  black");
  endplateZ = getImageID();
//measure area for use below
  run("Measure");
  endplateArea = getResult("Area");

//terminal image
//scale terminal image to correct for voxel anisotropy (as above)
  selectImage(termStack);
  getVoxelSize(vwidth, vheight, vdepth, vunit);
  zfactor = vdepth / vwidth;
  run("TransformJ Scale", "x-factor=1.0 y-factor=1.0 z-factor="+zfactor+" interpolation=linear");
  termScale = getImageID();
  
//rotate scaled terminal image by angles found above
  run("TransformJ Rotate", "z-angle=0.0 y-angle=" + yRot + " x-angle=" + xRot + " interpolation=[nearest neighbor] background=0.0 adjust");

  
//NEXT LINE IS FOR DEBUGGING
//save rotated image
//  saveAs("tiff", outputDir + filename + "_rotatedTerminal");

  
//create z-proj of rotated terminal stack
  run("Z Project...", "  projection=[Max Intensity]");
  setThreshold(1, 255);
  run("Convert to Mask", "  black");
  terminalZ = getImageID();
//measure area
  run("Measure");
  terminalArea = getResult("Area");

//adjust canvas side with zero fill based on center so that when image calculator runs the centers of the images will be aligned.
//first find max width and height two images to match sizes
  selectImage(endplateZ);
  endpW = getWidth();
  endpH = getHeight();

  selectImage(terminalZ);
  termW = getWidth();
  termH = getHeight();
  
  if(endpW > termW) 
    maxW = endpW;
  else
    maxW = termW;
	
  if(endpH > termH) 
    maxH = endpH;
  else
    maxH = termH;
//then adjust canvas size
  selectImage(endplateZ);
  run("Canvas Size...", "width=maxW height=maxH position=Center zero");
//NEXT LINE IS FOR DEBUGGING
//saveAs("tiff", outputDir + filename + "_maxEndplateZ");

  selectImage(terminalZ);
  run("Canvas Size...", "width=maxW height=maxH position=Center zero");
//NEXT LINE IS FOR DEBUGGING
//saveAs("tiff", outputDir + filename + "_maxTerminalZ");

//create merged image to save
  selectImage(endplateZ);
  red = getTitle();
    
  selectImage(terminalZ);
  green = getTitle();

  run("Merge Channels...", "c1=["+red+"] c2=["+green+"] create keep");
  saveAs("Jpeg", outputDir + filename + "_overlap");

//create image of overlap and find area
  imageCalculator("AND create", endplateZ,terminalZ);
  setThreshold(1, 255);
  run("Convert to Mask", "  black");
  overlapZ = getImageID();
  run("Measure");
  overlapArea = getResult("Area");

//NEXT LINE IS FOR DEBUGGING
//  saveAs("tiff", outputDir + filename + "_maxOverlapZ");

//calculate overlap percentage: overlapZ (terminalZ AND endplateZ) area divided by endplate area
	if(endplateArea > 0) {
		overlapPerc = overlapArea / endplateArea;
	} else {
		overlapPerc = 0;
		print("["+batchLog+"]", "WARNING: " + filename + " - endplate area is 0, cannot calculate overlap\n");
	}

  return newArray(xRot, yRot, overlapPerc, endplateZ, terminalArea, endplateArea);

} //end synapticOverlap function

function enFaceDispersion(image) {
//requires a binary z-projection
  selectImage(image);
//set threshold and measure area of z-projection
  setThreshold(1, 255);
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

  //save dispersion image stack projection
  path = outputDir + filename + "_enFaceDisp";
  saveAs("Jpeg", path);

  //return dispersion area
  return dispenface;

}//end dispersion function

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

 /*
  * Function to count the number of discrete endplate sections
  * Requires the 3D Objects Counter plugin
  * https://imagej.nih.gov/ij/plugins/track/objects.html
  */
function fragmentation(fimage) {
  selectImage(fimage);
  run("Clear Results");  
//run 3D Object Counter
//no min size; filtering takes care of noise (FYI, 575 voxels = about 1 cubic micron)
run("Object Counter3D", "threshold=1 slice=1 min=255 max=9999999 particles dot=5 numbers font=10 summary");
  frag = newArray(nResults+1);
  frag[0] = nResults;
  for (k=0; k<nResults; k++){
    frag[k+1] = getResult("Volume", k);
  }
  return frag; 
}

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
 *    auto_threshold.jar (custom code, possibly no longer needed)
 *    loci_tools.jar: https://docs.openmicroscopy.org/bio-formats/5.9.2/
 *    3D toolkit: http://ij-plugins.sourceforge.net/plugins/3d-toolkit/index.html
 *  TODO: put in URL for downloading all these
 * 
 * INPUT: a folder of 2-color .tiff documents.  Each tiff should contain one NMJ
 * 
 * @author Aaron Johnson
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
//TODO: Create options to save files
  saveMessage = "When the analysis is complete would you like to save the thresholded image stacks of the terminal and endplate and the maximum z-projections of the rotated endplates from the dispersion and synaptic overlap measures?"
//message to user
//if yes then saveImage = TRUE

//decrease the run time by not displaying new images
//  setBatchMode(true); 

//create a TimeStamp to record day and time analysis took place
  startTime = timeStamp();
  
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
    "filename\t" + "termVol\t" + "endplateVol\t" + "convexVol\t" + "dispRatio\t" + 
	"xRot\t" + "yRot\t" + "overlap\t" + "efDispRatio\t" + "frag\t"+ "fragvol\n");

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
	  print("["+totalResults+"]", filename + "\t");
	  
    //binarize stacks (threshold and remove noise)
	  selectImage(terminal);
	//smooth out noise with median filter (only 2D, runs on each slice)
    run("Median...", "radius=2 stack"); 
	
/**	//REMOVED FOR UIUC
	//setting threshold at 10 and removing noise with filtering
      setThreshold(10, 4095);
	  run("Convert to Mask", "  black");
**/

	//new (2.5 UIUC) converting to binary method
	  setAutoThreshold("Default dark stack");
	  run("Convert to Mask", "method=Default background=Dark black");
	  //Need all this filtering still?
      //run("Median 3D");
      //run("Morphological Erode 3D");
      //run("Morphological Dilate 3D");
	//update terminal variable to new thresholded image
	terminal = getImageID();
	  
	  selectImage(endplate);
    //smooth out noise with median filter (only 2D, runs on each slice)
      run("Median...", "radius=2 stack");
    //find maximum intensity in stack
      Stack.getStatistics(voxelCount, mean, min, max, stdDev);
	//stretch histogram to min and max
      setMinAndMax(min, max);

/**	//REMOVED FOR UIUC
	  //convert to 8-bit
    //only need next line if displying image
    //call("ij.ImagePlus.setDefault16bitRange", 0);
      run("8-bit");
	//threshold - TODO: evaluate 10 as lower cutoff
      setThreshold(10,255);
      run("Convert to Mask", " black");
**/

	//new (2.5 UIUC) converting to binary method
	  setAutoThreshold("Default dark stack");
	  run("Convert to Mask", "method=Default background=Dark black");
	  //Need all this filtering still?

	//filter and perform binary open (erode followed by dilation) to remove noise and isolated structures
      //run("Median 3D");
      //run("Morphological Erode 3D");
      //run("Morphological Dilate 3D");
	//update endplate variable to new thresholded image
	  endplate = getImageID();
	  
    //measure volumes
      termVol = stackVolume(terminal);
      endVol = stackVolume(endplate);
	  
//REMOVE AFTER DEBUGGING
//print("["+batchLog+"]", "stackVolume complete" + "\n");

    //calculate dispersion ratio for endplate
      convexVol = dispersion(endplate);
      dispRatio = convexVol / endVol;
//REMOVE AFTER DEBUGGING
//print("["+batchLog+"]", "convexVol and dispRatio complete" + "\n");

    //calculate synaptic overlap - function synapticOverlap returns an array that contains the x and y rotation angles and the synaptic overlap percentage
      synOverlap = synapticOverlap(endplate, terminal);
//REMOVE AFTER DEBUGGING
//print("["+batchLog+"]", "synOverlap complete" + "\n");
	  
	//calculate 2D dispersion of rotated en face endplate (returned as 4th element of the synOverlap array)
	  efDispRatio = enFaceDispersion(synOverlap[3]);
//REMOVE AFTER DEBUGGING
//print("["+batchLog+"]", "efDispRatio complete" + "\n");

    //calculate endplate fragmentation (# of discrete motor endplate clusters) and the volume of each of those fragments
      endplateFrag = fragmentation(endplate);
	  fragNum = endplateFrag[0];
//REMOVE AFTER DEBUGGING
//print("["+batchLog+"]", "endplateFrag complete" + "\n");

    //Add the results to total results file
      print("["+totalResults+"]",
        d2s(termVol, 0) + "\t" + d2s(endVol, 0) + "\t" + d2s(convexVol, 0) + "\t" 
		+ dispRatio + "\t" + synOverlap[0] + "\t" + synOverlap[1] + "\t" 
		+ synOverlap[2] + "\t" + efDispRatio + "\t" + fragNum);
      for (k=1; k<lengthOf(endplateFrag); k++) {
	    print("["+totalResults+"]", "\t" + endplateFrag[k]);
	  }
      Array.print(endplateFrag); 
	  print("["+totalResults+"]", "\n");
	  
//save images for debugging
//if (saveImage) then save the images
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
  save(outputDir + "TotalResults_" + startTime + ".txt");
//REMOVE AFTER DEBUGGING
//  save("C:/Users/JOHNSON/Documents/My Dropbox/1_Projects/Dissertation/Stats/" + "results_" + startTime + ".txt");
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
 * Measure dispersion ratio by copying the ROI to a new image stack, removing 
 * the outliers, then for each slice; draw and select the convex hull (using 
 * external plugin), measure the area bounded by the convex hull, then 
 * calculate the convex hull volume.
 */
function dispersion(image) {
  selectImage(image);
  dispArea = 0;

//Solving the "banana problem"
//rotate the image to find the minimum convex hull perimeter - this will standardize the 
//reslice with linear transformation (same method as 3D projection) to make voxels square (.07x.07x.07 micron)
  selectImage(image);
  getVoxelSize(vwidth, vheight, vdepth, vunit);
  zfactor = vdepth / vwidth;
  run("TransformJ Scale", "x-factor=1.0 y-factor=1.0 z-factor="+zfactor+" interpolation=linear");
  epScaled = getImageID();

//find minimum convex hull in y-axis rotation
//rotate the resliced endplate stack; create 180 degree 3D projection with 1 degree rotations on y-axis - no need for interpolation b/c distance between stacks is now less than 1 pixel
  selectImage(epScaled);
  getVoxelSize(vwidth, vheight, vdepth, vunit);
  run("3D Project...", "projection=[Brightest Point] axis=Y-Axis slice="+vdepth+" initial=0 total=180 rotation=1 lower=1 upper=255 opacity=0 surface=0 interior=0");
//convert 3D projection to binary
  setThreshold(1, 255);
  run("Convert to Mask", "  black");
//find y rotation angle
  run("Set Measurements...", "  perimeter redirect=None decimal=2");
  run("Clear Results");
  minPerim = 100000;
  yRot = 0;
  for(j=1; j<180; j++) {
    setSlice(j);
	run("NMJ Convex Hull");
	run("Measure");
    if(getResult("Perim.") < minPerim) {
      yRot = j-1;
      minPerim = getResult("Perim.");
    }
  } //end rotation for loop


//REMOVE AFTER DEBUGGING
//for debugging save results
//    selectWindow("Results");
//    saveAs("text", outputDir + filename + "maxareaY");


//after minimum perimeter is found, use TransformJ to rotate the resliced image to the minimum perimeter y-axis angle
  selectImage(epScaled);
  run("TransformJ Rotate", "z-angle=0.0 y-angle=" + yRot + " x-angle=0.0 interpolation=[nearest neighbor] background=0.0 adjust");
  epScaledYRot = getImageID();
  
//find minimum convex hull perimeter in x-axis rotation
//from newly rotated stack (epScaledYRot) create 180 degree 3D projection with 1 degree rotations on x-axis, with interpolation
  getVoxelSize(vwidth, vheight, vdepth, vunit);
//convert 3D projection to binary
  run("3D Project...", "projection=[Brightest Point] axis=X-Axis slice="+vdepth+" initial=0 total=180 rotation=1 lower=1 upper=255 opacity=0 surface=0 interior=0");
  setThreshold(1, 255);
  run("Convert to Mask", "  black");
//rotate find x rotation angle
  minPerim = 100000;
  xRot = 0;
  run("Clear Results");
  for(j=1; j<180; j++) {
    setSlice(j);
	run("NMJ Convex Hull");
	run("Measure");
    if(getResult("Perim.") < minPerim) {
      xRot = j-1;
      minPerim = getResult("Perim.");
    }
  } //end rotation for loop

  
//REMOVE AFTER DEBUGGING
//for debugging save results
//    selectWindow("Results");
//    saveAs("text", outputDir + filename + "maxareaX");


//when the minimum perimeter is found, use TransformJ to rotate epScaledYRot to the minimum perimeter x-axis angle
  selectImage(epScaledYRot);
  run("TransformJ Rotate", "z-angle=0.0 y-angle=0 x-angle=" + xRot + " interpolation=[nearest neighbor] background=0.0 adjust");
  epScaledYXRot = getImageID();

//calculate dispersion
  run("Set Measurements...", "area perimeter decimal=2");
  selectImage(epScaledYXRot);
  setThreshold(1, 255);
  run("Convert to Mask", "  black");
  
//Loop through slices and measure volume
  for (n=1; n<=nSlices; n++) {
    setSlice(n);
    run("NMJ Convex Hull");
	run("Measure");
    if (getResult("Perim.", nResults-1) != 0){
      dispArea = dispArea + getResult("Area", nResults-1);
    }
  }

  //calculate dispersion volume
  getVoxelSize(vwidth, vheight, vdepth, vunit);
  dispersionVol = dispArea * vdepth;

  //save dispersion image stack projection
  run("Z Project...", "  projection=[Max Intensity]");
  path = outputDir + filename + "_disp";
  saveAs("Jpeg", path);
  
  //return dispersion volume
  return dispersionVol;

}//end dispersion function


/**
2 * Function to measure the amount of overlap of the maximum projections of two stacks.
 * Rotates stack 1 to find the maximum area, rotates stack 2 by the same amount.
 */

function synapticOverlap(epStack, termStack) {
//reslice with linear transformation (same method as 3D projection) to make voxels square (.07x.07x.07 micron)
  selectImage(epStack);
  getVoxelSize(vwidth, vheight, vdepth, vunit);
  zfactor = vdepth / vwidth;
  run("TransformJ Scale", "x-factor=1.0 y-factor=1.0 z-factor="+zfactor+" interpolation=linear");
  epScaled = getImageID();

//find maximum area in y-axis rotation
//rotate the resliced endplate stack; create 180 degree 3D projection with 1 degree rotations on y-axis - no need for interpolation b/c distance between stacks is now less than 1 pixel
  selectImage(epScaled);
  getVoxelSize(vwidth, vheight, vdepth, vunit);
  run("3D Project...", "projection=[Brightest Point] axis=Y-Axis slice="+vdepth+" initial=0 total=180 rotation=1 lower=1 upper=255 opacity=0 surface=0 interior=0");
//convert 3D projection to binary
  setThreshold(1, 255);
  run("Convert to Mask", "  black");
//find y rotation angle
  run("Set Measurements...", "area limit redirect=None decimal=2");
  run("Clear Results");
  maxArea = 0;
  yRot = 0;
  for(j=1; j<180; j++) {
    setSlice(j);
	run("Measure");
    if(getResult("Area") > maxArea) {
      yRot = j-1;
      maxArea = getResult("Area");
    }
  } //end rotation for loop


//REMOVE AFTER DEBUGGING
//for debugging save results
//    selectWindow("Results");
//    saveAs("text", outputDir + filename + "maxareaY");


//after maximum area is found, use TransformJ to rotate the resliced image to the maximum area y-axis angle
  selectImage(epScaled);
  run("TransformJ Rotate", "z-angle=0.0 y-angle=" + yRot + " x-angle=0.0 interpolation=[nearest neighbor] background=0.0 adjust");
  epScaledYRot = getImageID();
  
//find maximum area in x-axis rotation
//from newly rotated stack (epScaledYRot) create 180 degree 3D projection with 1 degree rotations on x-axis, with interpolation
  getVoxelSize(vwidth, vheight, vdepth, vunit);
  run("3D Project...", "projection=[Brightest Point] axis=X-Axis slice="+vdepth+" initial=0 total=180 rotation=1 lower=1 upper=255 opacity=0 surface=0 interior=0");
//convert 3D projection to binary
  setThreshold(1, 255);
  run("Convert to Mask", "  black");
//rotate find x rotation angle
  maxArea = 0;
  xRot = 0;
  run("Clear Results");
  for(j=1; j<180; j++) {
    setSlice(j);
	run("Measure");
    if(getResult("Area") > maxArea) {
      xRot = j-1;
      maxArea = getResult("Area");
    }
  } //end rotation for loop

  
//REMOVE AFTER DEBUGGING
//for debugging save results
//    selectWindow("Results");
//    saveAs("text", outputDir + filename + "maxareaX");


//when the maximum area is found, use TransformJ to rotate epScaledYRot to the maximum area x-axis angle
  selectImage(epScaledYRot);
  run("TransformJ Rotate", "z-angle=0.0 y-angle=0 x-angle=" + xRot + " interpolation=[nearest neighbor] background=0.0 adjust");
  epScaledYXRot = getImageID();
  
  
//REMOVE AFTER DEBUGGING
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

  
//REMOVE AFTER DEBUGGING
//save rotated image
//  saveAs("tiff", outputDir + filename + "_rotatedTerminal");

  
//create z-proj of rotated terminal stack
  run("Z Project...", "  projection=[Max Intensity]");
  setThreshold(1, 255);
  run("Convert to Mask", "  black");
  terminalZ = getImageID();

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
//REMOVE AFTER DEBUGGING
//saveAs("tiff", outputDir + filename + "_maxEndplateZ");

  selectImage(terminalZ);
  run("Canvas Size...", "width=maxW height=maxH position=Center zero");
//REMOVE AFTER DEBUGGING
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

//REMOVE AFTER DEBUGGING
//  saveAs("tiff", outputDir + filename + "_maxOverlapZ");
  
//calculate overlap percentage: overlapZ (terminalZ AND endplateZ) area divided by endplate area
	overlapPerc = overlapArea / endplateArea;

  return newArray(xRot, yRot, overlapPerc, endplateZ);

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
  dispenface = dispArea/stainedArea;

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

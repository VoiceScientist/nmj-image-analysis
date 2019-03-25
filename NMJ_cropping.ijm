/**
 * This ImageJ macro assists with cropping and save substacks of
 * individual NMJs from a confocal image stack of multiple NMJs
 * 
 * INPUT: an open stack (any format)
 * OUTPUT: cropped images with the extension "-n", where "n" is the ROI number. Also saves the ROIs.
 * 
 * @author Aaron Johnson
 *
 * Version 1.0
 * 10/05/2015
 * First version, works on an open 2-color image.
 * 
 * Version 1.1
 * 09/24/2018
 * Updated to use the lastIndexOf to find the "." before the file extension.
 * Changed save directory to NYU research lab "ready for analysis" folder.
 *
 * Version 1.3
 * 03/24/2019
 * Added option to create 3D projection.
 */


macro "NMJ Cropping [f10]" {
currImage = getImageID();
filename = substring(getTitle(), 0, lastIndexOf(getTitle(), "."));
dir = getDirectory("image");
//change path below to desired save directory - be sure to put two back slashes between directories
saveDir = "R:\\johnsa30lab\\johnsa30labspace\\1-Projects\\Vocal Dose - K23 - Animal\\NMJ Confocal\\Ready for Analysis"
run("Z Project...", "projection=[Max Intensity]");
run("Enhance Contrast", "saturated=0.35");

projection = getBoolean("Create 3D Projection?");

if(projection) {
    selectImage(currImage);
	run("3D Project...", "projection=[Brightest Point] axis=Y-Axis slice=1 initial=0 total=360 rotation=10 lower=1 upper=255 opacity=0 surface=100 interior=50");
}

//
waitForUser('Select NMJs','make selections on Z-projection and add to ROI manager by pressing T. When all selections have been made click OK');

//for loop to duplicate ROIs
n = roiManager("count");
  for (i=0; i<n; i++) {
	  selectImage(currImage);
      roiManager("select", i);
      run("Duplicate...", "duplicate");
	  setBackgroundColor(0, 0, 0);
	  run("Clear Outside");
	  imageNum = i+1;
	  saveAs("tiff", saveDir + File.separator + filename + "-" + imageNum);
  }

roiManager("Save", dir + File.separator + filename + "-ROIs.zip");
roiManager("reset");

//close open images
    while (nImages>0) {
    selectImage(nImages);
    close();
  }
}

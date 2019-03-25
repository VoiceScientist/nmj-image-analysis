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
 *
 * Version 1.4
 * 03/25/2019
 * Changed to run on folder of images.
 */


macro "NMJ Cropping - Folder [f10]" {

//select directory of .tiff images to process
  dir = getDirectory("Choose a directory of .lsm images");
  dirlist = getFileList(dir);

//create directory for new images
  saveDir = dir + "cropped" + File.separator;
  File.makeDirectory(saveDir);

  for(i=0; i<dirlist.length; i++) {
    String.resetBuffer;
    currfile = dir+dirlist[i];

    if(endsWith(currfile, "lsm")) {
      open(currfile);
	  currImage = getImageID();
	  filename = substring(getTitle(), 0, lastIndexOf(getTitle(), "."));
	  run("Z Project...", "projection=[Max Intensity]");
	  run("Enhance Contrast", "saturated=0.35");
	  run("Make Composite");

	//ask if user would like to create a 3D projection
	  projection = getBoolean("Create 3D Projection?");
	  if(projection) {
		  selectImage(currImage);
		  run("3D Project...", "projection=[Brightest Point] axis=Y-Axis slice=1 initial=0 total=360 rotation=10 lower=1 upper=255 opacity=0 surface=100 interior=50");
		  }

	//Wait for use to create ROI for each NMJ 
	  waitForUser('Select NMJs','make selections on Z-projection and add to ROI manager by pressing T. When all selections have been made click OK');

	//create new cropped image(s) by duplicating each ROIs to new image and saving as a tiff
	  n = roiManager("count");
	  for (j=0; j<n; j++) {
		  selectImage(currImage);
		  roiManager("select", j);
		  run("Duplicate...", "duplicate");
		//delete any area outside of a non-rectangular ROI in the new image
		  setBackgroundColor(0, 0, 0);
		  roiManager("select", j);
		  run("Clear Outside", "stack");
		  imageNum = j+1;
		  saveAs("tiff", saveDir + filename + "-" + imageNum);
		  }
	
	//save ROIs in original image folder and reset (clear) ROI Manager
	  roiManager("Save", dir + filename + "-ROIs.zip");
	  roiManager("reset");

	//close open images
	  while (nImages>0) {
      selectImage(nImages);
      close();
	  }

    } //end if(.lsm document)

  } //end for loop through files in directory

  showMessage("Macro Complete");
} //end macro
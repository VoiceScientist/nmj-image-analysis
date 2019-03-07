//Macro to assist with labeling structures on a dynamic MRI AVI 
//Requires an open image (avi); runs on current frame


macro "MRI Labeling [f10]" {

//set up variables and directories
sourceAVI = getImageID();
currentDirectory = getDirectory("image");
imageName = getTitle();
imageNameArray = split(imageName, "_");
//avi filename format is "liveview_MIDID09_Task2_ScanD.dat_video.avi"
//set filename variables
for(i=0; i<imageNameArray.length; i++) {
if(startsWith(imageNameArray[i],"MID") 
	id = imageNameArray[i];
else if(startsWith(imageNameArray[i], "Task")
	task = imageNameArray[i];
else if(startsWith(imageNameArray[i], "Scan")
	scan = imageNameArray[i];
}

//Duplicate current frame
run("Duplicate...", "use");
run("Duplicate...", "title="+task+"_"+id+"_"+scan);

// ensure no selections are initially made
run("Select None");
run("Clear Results");

//Begin identifying structures
//Prompt to put spot on each anatomical location
//1a. Lowest point on superior lip (point)
setTool("point");
waitForUser('Selection Required','Mark the lowest point on superior lip, then click OK')
roiManager("Add");
roiManager("Select", roiManager("count")-1);
roiManager("Rename", "superior_lip");
//maybe there is a better way to do the following line
superior_lip_index = roiManager("count")-1
//TODO get coordinates and assign to array
//SOME SORT OF MEASURE COMMAND
superior_lip_xy = 

//2a. Highest point on inferior lip (point)
waitForUser('Selection Required','Mark the highest point on the inferior lip, then click OK')
roiManager("Add");
roiManager("Select", roiManager("count")-1);
roiManager("Rename", "inferior_lip");
inferior_lip_xy = 

//3b. Spina of the upper jaw (hard palate) (point)
waitForUser('Selection Required','Mark the spina of the upper jaw (hard palate), then click OK')
roiManager("Add");
roiManager("Select", roiManager("count")-1);
roiManager("Rename", "spina");

//4bd. Lower front edge of the mandible (point)
waitForUser('Selection Required','Mark the lower front edge of the mandible, then click OK')
roiManager("Add");
roiManager("Select", roiManager("count")-1);
roiManager("Rename", "front_mandible");

//5c. Superior surface of the mandible (line)
setTool("line");
waitForUser('Selection Required','Draw a line along the superior surface of the mandible, then click OK')
roiManager("Add");
roiManager("Select", roiManager("count")-1);
roiManager("Rename", "superior_mandible");

//6c. Highest cranial point of the tongue (point)
setTool("point");
waitForUser('Selection Required','Mark the highest cranial point of the tongue, then click OK')
roiManager("Add");
roiManager("Select", roiManager("count")-1);
roiManager("Rename", "tongue_highest");

//7d. Posterior wall of the laryngopharynx (line)
setTool("point");
waitForUser('Selection Required','Draw a line along the posterior wall of the laryngopharynx, then click OK')
roiManager("Add");
roiManager("Select", roiManager("count")-1);
roiManager("Rename", "laryngopharynx");

//8e. Posterior contour of the tongue (contour)
setTool("freeline");
waitForUser('Selection Required','Outline the posterior contour of the tongue by freehand drawing a line, then click OK')
roiManager("Add");
roiManager("Select", roiManager("count")-1);
roiManager("Rename", "tongue_posterior");
//9e. Posterior wall of oropharynx (line)
setTool("line");
waitForUser('Selection Required','Draw a straight line along the posterior wall of the oropharynx, then click OK')
roiManager("Add");
roiManager("Select", roiManager("count")-1);
roiManager("Rename", "oropharynx");

//10f. Extended contour of the hard palate (line) ***maybe a point
waitForUser('Selection Required','Draw a line extending the contour of the hard palate above the soft palate, then click OK')
roiManager("Add");
roiManager("Select", roiManager("count")-1);
roiManager("Rename", "hard_palate");
//11f. Lowermost part of the uvula contour (point)
setTool("point");
waitForUser('Selection Required','Mark the lowermost part of the uvula contour, then click OK')
roiManager("Add");
roiManager("Select", roiManager("count")-1);
roiManager("Rename", "uvula");
//12g. Cranial-most part of the dens axis (point)
waitForUser('Selection Required','Mark the dens axis, then click OK')
roiManager("Add");
roiManager("Select", roiManager("count")-1);
roiManager("Rename", "densaxis");

//13g. Caudo-anterior edge of the sixth vertebra (point) (measurements 12 and 13 create the auxiliary line A for measuring laryngeal height)
waitForUser('Selection Required','Mark the caudo-anterior edge of the sixth vertebra, then click OK')
roiManager("Add");
roiManager("Select", roiManager("count")-1);
roiManager("Rename", "vertebra");

//14g. Anterior commissure (point) (will draw horizontal line - auxiliary line B - from this point to intersect auxiliary line A to measure laryngeal height)
waitForUser('Selection Required','Mark the anterior comissure of the vocal folds, then click OK')
roiManager("Add");
roiManager("Select", roiManager("count")-1);
roiManager("Rename", "anterior_commissure");

//15h. Superior-posterior point of vocal process (point)
waitForUser('Selection Required','Mark the superior-posterior point of the vocal process, then click OK')
roiManager("Add");
roiManager("Select", roiManager("count")-1);
roiManager("Rename", "vocal_process");

//Save ROIs
roiManager("Save", currentDirectory
"R:/johnsa30lab/johnsa30labspace/1-Projects/Singing Styles MRI and Endoscopy/MRI Analysis/ID09_Task2_Roi.zip");

//run in batch mode to increase speed of measurements
setBatchMode(true);

//create a text file to store measurements
//TODO

//Calculate dimensions based on ROI points
//1. Lip opening
makeLine(superior_lip_xy[0], superior_lip_xy[1], inferior_lip_xy[0], inferior_lip_xy[1]);
//measure the length of the line above and that's the lip opening
//TODO

lip_opening = getResult("Length", nResults-1);

//2. Next measurement


//Print all results to a log file and save
//TODO

//Save image with selections
roiManager("UseNames", "true");
run("Flatten");
saveAs("Jpeg", "R:/johnsa30lab/johnsa30labspace/1-Projects/Singing Styles MRI and Endoscopy/MRI Analysis/ID09_Task2.jpg");

//Close all open windows except for sourceAVI
//close open images
for (i=nImages; i<1; i--) {
  selectImage(i);
  if(getImageID()!=sourceAVI)
	  close();
}

//close the results and threshold windows if open
if (isOpen("Results")) {
	selectWindow("Results");
	run("Close");
	}
if (isOpen("Threshold")) {
	selectWindow("Threshold");
	run("Close");
	}

//macro complete
showMessage("Macro Complete. Select next image to measure and run macro again.");
}


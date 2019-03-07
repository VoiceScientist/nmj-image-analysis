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
	if(startsWith(imageNameArray[i],"MID")) 
		subjectid = imageNameArray[i];
	else if(startsWith(imageNameArray[i], "Task"))
		task = imageNameArray[i];
	else if(startsWith(imageNameArray[i], "Scan"))
		scan = imageNameArray[i];
}

//Duplicate current frame
  currImage = task+"_"+subjectid+"_"+scan;
  run("Duplicate...", "title="+currImage);

// ensure no selections are initially made
  run("Select None");
  run("Clear Results");
  roiManager("reset");

//Begin identifying structures
//Prompt to put spot on each anatomical location
//1a. Lowest point on superior lip (point)
  setTool("point");
  waitForUser('Selection Required','Mark the lowest point on superior lip, then click OK');
  superior_lip_xy = nameGetXY("superior_lip");

//2a. Highest point on inferior lip (point)
  waitForUser('Selection Required','Mark the highest point on the inferior lip, then click OK');
  inferior_lip_xy = nameGetXY("inferior_lip");

//3b. Spina of the upper jaw (hard palate) (point)
  waitForUser('Selection Required','Mark the spina of the upper jaw (hard palate), then click OK');
  spina_xy = nameGetXY("spina");

//4bd. Lower front edge of the mandible (point)
  waitForUser('Selection Required','Mark the lower front edge of the mandible, then click OK');
  front_mandible_xy = nameGetXY("front_mandible");

//5c. Superior surface of the mandible (line)
  setTool("line");
  waitForUser('Selection Required','Draw a line along the superior surface of the mandible, then click OK');
  superior_mandible_xy = nameGetXY("superior_mandible");

//6c. Highest cranial point of the tongue (point)
  setTool("point");
  waitForUser('Selection Required','Mark the highest cranial point of the tongue, then click OK');
  tongue_highest_xy = nameGetXY("tongue_highest");

//7d. Posterior wall of the laryngopharynx (line)
  setTool("line");
  waitForUser('Selection Required','Draw a line along the posterior wall of the laryngopharynx, then click OK');
  laryngopharynx_xy = nameGetXY("laryngopharynx");

//8e. Posterior contour of the tongue (contour)
  setTool("freeline");
  waitForUser('Selection Required','Outline the posterior contour of the tongue by freehand drawing a line, then click OK');
  roiManager("Add");
  roiManager("Select", roiManager("count")-1);
  roiManager("Rename", "tongue_posterior");
  //TODO not sure what to do with this contour

//9e. Posterior wall of oropharynx (line)
  setTool("line");
  waitForUser('Selection Required','Draw a straight line along the posterior wall of the oropharynx, then click OK');
  oropharynx_xy = nameGetXY("oropharynx");

//10f. Extended contour of the hard palate (line) ***maybe a point
  waitForUser('Selection Required','Draw a line extending the contour of the hard palate above the soft palate, then click OK');
  hard_palate_xy = nameGetXY("hard_palate");

//11f. Lowermost part of the uvula contour (point)
  setTool("point");
  waitForUser('Selection Required','Mark the lowermost part of the uvula contour, then click OK');
  uvula_xy = nameGetXY("uvula");

//12g. Cranial-most part of the dens axis (point)
  waitForUser('Selection Required','Mark the dens axis, then click OK');
  densaxis_xy = nameGetXY("densaxis");

//13g. Caudo-anterior edge of the sixth vertebra (point) (measurements 12 and 13 create the auxiliary line A for measuring laryngeal height)
  waitForUser('Selection Required','Mark the caudo-anterior edge of the sixth vertebra, then click OK');
  vertebra_xy = nameGetXY("vertebra");

//14g. Anterior commissure (point) (will draw horizontal line - auxiliary line B - from this point to intersect auxiliary line A to measure laryngeal height)
  waitForUser('Selection Required','Mark the anterior comissure of the vocal folds, then click OK');
  anterior_commissure_xy = nameGetXY("anterior_commissure");

//15h. Superior-posterior point of vocal process (point)
  waitForUser('Selection Required','Mark the superior-posterior point of the vocal process, then click OK');
  vocal_process_xy = nameGetXY("vocal_process");

//Save ROIs
  roiManager("Save", currentDirectory + currImage + "_ROI.zip");

//run in batch mode to increase speed of measurements
  setBatchMode(true);

//create text window to save the cumulative results 
  totalResults = "TotalResults";
  run("Text Window...", "name="+totalResults+" width=40 height=20");
 
//print header for results TODO update headers
  print("["+totalResults+"]", "filename\t" 
  + "a-lip_opening," + "b-jaw_opening," + "c-tongue_dorsum," 
  + "d-jaw_protrusion," + "e-oropharynx_width," + "f-uvula_elevation,"
  + "g-larynx_position," + "h-angle_of_larynx_tilt\n");

//add image name to output
  print("["+totalResults+"]", currImage + ",");
	
//create a text file to store measurements
//TODO

//Calculate dimensions based on ROI points
//a lip opening: distance between the lips
//Calculate distance based on points (using the Pythagorean theorem!)
//lip_opening = lengthFromPoints(superior_lip_xy, inferior_lip_xy); //not doing - want difference in y only
  lip_opening = abs(superior_lip_xy[1] - inferior_lip_xy[1]);
  print("["+totalResults+"]", lip_opening + ",");

//b jaw opening: jaw opening, defined as the distance between the spina of the upper jaw and the lower front edge of the mandible
  jaw_opening = lengthFromPoints(spina_xy, front_mandible_xy);
  print("["+totalResults+"]", jaw_opening + ",");

//c tongue dorsum: defined as the maximum distance from a line touching the lower contour of the mandible and up to the highest cranial point of the tongue contour
//TODO how to deal with line?
  tongue_dorsum = 0;

//d jaw protrusion: the distance between the lower front edge of the mandible and the mucosal cover of the spine at a 90-degree angle
//TODO how to deal with line?
  jaw_protrusion = 0;
  
//e oropharynx width: pharynx width measured as the shortest distance between the posterior contour of the tongue, and the mucosal cover of the spine
  oropharynx_width = 0;

//f uvula elevation: the distance between a line extending the upper contour of the hard palate and a parallel line tangent to the lowermost part of the uvula contour
  uvula_elevation = 0;

//An auxiliary line (A) was drawn for the measurement of the larynx position and laryngeal tilting. This auxiliary line connects the cranial-most part of the dens axis and the caudo-anterior edge of the sixth vertebra.
  makeLine(densaxis_xy[0], densaxis_xy[1], vertebra_xy[0], vertebra_xy[1]);

//g larynx position: the distance from the cranial-most part of the dens axis to the point where auxiliary line A crosses a line (auxiliary line B) from the anterior commissure rectangular to auxiliary line A
  larynx_position = 0;
  
//h angle of larynx tilt: the larynx tilt measured as the angle between auxiliary line A and a line from the anterior commissure to the vocal process
  angle_of_larynx_tilt = 0;

//Print all results to a log file and save
  print("["+totalResults+"]",
	lip_opening + ","
	+ jaw_opening + ","
	+ tongue_dorsum + ","
	+ jaw_protrusion + ","
	+ oropharynx_width + ","
	+ uvula_elevation + ","
	+ larynx_position + ","
	+ angle_of_larynx_tilt + "\n");

  selectWindow("TotalResults");
  save(currentDirectory + imageName + "_results.txt");
  run("Close");

//Save image with selections
  roiManager("show all with labels");
  roiManager("UseNames", "true");
  run("Flatten");
  saveAs("Jpeg", currentDirectory + imageName + ".jpg");
  
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

//macro complete
  showMessage("Macro Complete. Select next image to measure and run macro again.");
}

function nameGetXY(name) {
  roiManager("Add");
  roiManager("Select", roiManager("count")-1);
  roiManager("Rename", name);
  run("Measure");
  if(IJ.getToolName() == "line") {
	  lineInfo = newArray(5);
	  getLine(lineInfo[0], lineInfo[1], lineInfo[2], lineInfo[3], lineInfo[4]);
	  return lineInfo;
  }
  else {
	  return newArray(getResult("X", nResults-1), getResult("Y", nResults-1));
  }
}

function lengthFromPoints(x1y1, x2y2) {
	return sqrt(
	(pow(abs(x1y1[0] - x2y2[0]), 2)) +
	(pow(abs(x1y1[1] - x2y2[1]), 2))
	);
}	
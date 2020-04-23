// ThunderFISH v.1.0 preprocessing script for RNA-FISH images //
//
// by Aleksander Szczurek, University of Oxford 2019
 
/////// 1) SPLIT ORIGINAL 3D STACK INTO 2D IMAGES OF FISH AND MASKS /////////
////////////////////////////////////////////////////////////////////////////
   
print("\\Clear")
print("1/3 Choose folder containing original data stacks (.Tiff) . . .");       // Ask for input and output dirs:
waitForUser("1/3  Choose folder containing original data stacks (.Tiff) . . ."); 
input = getDirectory("Choose a Directory"); 
print("2/3  Choose output folder for FISH channel . . .");
waitForUser("2/3 Choose output folder for FISH channel . . .");
outputFISH = getDirectory("Choose a Directory");
print("3/3  Choose output folder for MASK channel . . .");
waitForUser("3/3 Choose output folder for MASK channel . . .");
outputMASK = getDirectory("Choose a Directory");
wait(300); print(". . . PROCESSING . . .");

function splitter(input, output1, output2, filename) {
	       while (nImages>0) {                                                 // close open images 
          selectImage(nImages); 
          close();       }

			fileName = substring(filename,0,lengthOf(filename)-4);             // deletes '.tif' from file name
      		open(input + filename);
       		imgName=getTitle();

				selectWindow(imgName);
				run("Make Substack...", "  slices=61-90");                     //@user - change according to your number of Z-slices
        		imgNameFISH=getTitle();
					run("Z Project...", "projection=[Max Intensity]");
					run("Subtract Background...", "rolling=2");                //@user
					run("Add Specified Noise...", "standard=1"); 
					saveAs("Tiff", output1+fileName+"_Max_FISH"+"_C0001.tif"); // don't change the ending!

				selectWindow(imgName);
				run("Make Substack...", "  slices=61-90");                     //@user - change according to your number of Z-slices
        		imgNameMASK=getTitle();
					run("Z Project...", "projection=[Average Intensity]");
					run("Subtract Background...", "rolling=150 sliding");
					saveAs("Tiff", output2+fileName+"_Ave_MASK"+"_C0002.tif"); // don't change the ending!
}

setBatchMode(true); 
list = getFileList(input);
for (i = 0; i < list.length; i++)
        splitter(input, outputFISH, outputMASK, list[i]);
setBatchMode(false);
close();
wait(300);
print("Progress 1/6");



////////// 2) INSERT 2D FISH IMAGES INTO SINGLE SUB-DIRECTORIES ////////////
////////////////////////////////////////////////////////////////////////////
close("*");
listFiles = getFileList(outputFISH);     // list of 2D-FISH images

setBatchMode(true); 
for (n = 0; n < listFiles.length; n++){                                  // n corresponds to 2D-FISH image no.
	if(endsWith(listFiles[n],".tif")){                                   // Condition to process only the main iamge not resulting images, works well
		newDir = outputFISH + listFiles[n];
		folderName = substring(listFiles[n],0,lengthOf(listFiles[n])-4); //cuts file extension from the file name
		File.makeDirectory(outputFISH+folderName);                       // create a folder per .tiff file correctly
		outputPath = outputFISH+folderName;
		open(outputFISH + listFiles[n]); image=getTitle();
		imgName_Final=getTitle();
		saveAs("Tiff",  outputPath +"\\" +listFiles[n]);
		close(image);
		wait(500);
	}
}
setBatchMode(false);
wait(500);

//delete .tiff files in outputFISH directory:
setBatchMode(true); 
	for (n = 0; n < listFiles.length; n++){  
		if(endsWith(listFiles[n],".tif")){
			File.delete(outputFISH + listFiles[n]);                      // here deletes .tif files from the original dir as they're already in folder
		}}
setBatchMode(false); 
wait(500);
print("Progress 2/6");




////////////// 3) Produce masks using 2D-background images /////////////////
////////////////////////////////////////////////////////////////////////////
close("*");

function masker(input, output, filename) {
	fileName = substring(filename,0,lengthOf(filename)-4); // deletes '.tif' from file name
        open(input + filename);
        run("Median...", "radius=5");                      //@user
		//run("Scale...", "x=0.5 y=0.5 width=600 height=600 interpolation=Bilinear average create");
		setAutoThreshold("Huang");
			setOption("BlackBackground", false);
			run("Convert to Mask");
			run("Invert");
			//run("Fill Holes");
			run("Watershed"); 
//			run("16-bit"); //optional, perhaps necessary
        	run("Invert LUT"); 
        	saveAs("Tiff", output + fileName + "_MASK");	
}

File.makeDirectory(outputMASK+"masks");                    // make a subdirectory to save Masks there
outputFINAL=outputMASK+"/masks/";                          // this is directory that the next step will be operating in!

setBatchMode(true); 
listMASK = getFileList(outputMASK);   
for (i = 0; i < listMASK.length; i++)
	if(endsWith(listMASK[i],"C0002.tif")){
        masker(outputMASK, outputFINAL, listMASK[i]);
}
setBatchMode(false);
close();
wait(500);
print("Progress 3/6");


////////////// 4) Produce single cell masks using 2D-MASK images of full field of view /////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////
if (isOpen("ROI Manager")) {
     selectWindow("ROI Manager");
     run("Close");
}

File.makeDirectory(outputFINAL+"singlecellmasks");     // make a subdir for single cell masks
outputFINALsc=outputFINAL+"/singlecellmasks/";         // variable storing name of that subdir

function SCcutter(inputPath, output, filename) {       // this is a definition of a function producing single masks
	open(inputPath + filename);
	setAutoThreshold("Default");
	run("Invert");
	run("Analyze Particles...", "size=6000-Infinity pixel pixel circularity=0.75-1.00 show=Masks exclude clear summarize add in_situ"); // @user - adjust your single cell stringecy!
	setBackgroundColor(0, 0, 0);
	print(roiManager("count"));
	for (i=1; i<roiManager("count"); i++) {
		roiManager("Select", i);
		setForegroundColor(255, 255, 255);
		run("Fill", "slice");
		run("Clear Outside");
		saveAs("Tiff", output + "\\"+i+"_SingleCellMask.tif");    
	}	
} 

listSCmasks = getFileList(outputFINAL);     
setBatchMode(true); 
for (m = 0; m < listSCmasks.length; m++){  
	if(endsWith(listSCmasks[m],"_MASK.tif")){  
		newDir = outputFINALsc + listSCmasks[m];
		folderName = substring(listSCmasks[m],0,lengthOf(listSCmasks[m])-23); // cuts out the core name of image, i.e. without name extension
		File.makeDirectory(outputFINALsc+folderName);
		outputPath = outputFINALsc+folderName;
	    SCcutter(outputFINAL, outputPath, listSCmasks[m]); 
	    if (isOpen("ROI Manager")) {
        selectWindow("ROI Manager");
        run("Close");
}
	}
}
setBatchMode(false);

	      while (nImages>0) { // close any open images 
          selectImage(nImages); 
          close();       }
print("Progress 4/6");        
print("4) Now review your single cell masks and delete the ones that you don't like !");
print("    Manually remove accidentally merged cells or excessively cut cells !");
waitForUser("Delete your poor-quality cells from \\\\outMASKS\\masks\\singlecellmasks NOW! Then press OK !"); 
waitForUser("GREAT! You are ready for the second part  !"); 
wait(300);


////////////////// 5) Use single cell masks to produce single cell RNA-FISH images /////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////

end_TRITC="_Max_FISH"+"_C0001.tif";                   // those name extensions are etablished earlier in the code
end_Masks="_SingleCellMask.tif";

function multiplier(inputTRITC, inputMasks) {
setBatchMode(true);
listTRITC = getFileList(inputTRITC);
listMaskFiles = getFileList(inputMasks);
for (i = 0; i < listTRITC.length; i++){     
				if (endsWith(listTRITC[i], ".tif")){
					core = substring(listTRITC[i],0,lengthOf(listTRITC[i])-19);    // name ending: "_Max_FISH"+"_C0001.tif"
					open(inputTRITC + core + end_TRITC);
					imgName_TRITC=getTitle();
				}
}

for (k = 0; k < listMaskFiles.length; k++){            // k - single cell masks
				if (endsWith(listMaskFiles[k], "_SingleCellMask.tif")){
						core = substring(listMaskFiles[k],0,lengthOf(listMaskFiles[k])-19); 
						print(core);
   						open(inputMasks + core + end_Masks);
   						run("16-bit");
   						run("Select All");              // Multiplies 255 background value of the single cell mask to remove better out-of-ROI signals ...
						run("Multiply...", "value=10"); // ... and his value might have to be adjusted (increased) as it depends on the FISH image intensity  //@user
						imgName_Mask=getTitle();  					
   					imageCalculator("Subtract create stack", imgName_TRITC ,imgName_Mask);
   					imgName_Final=getTitle();		
					
							//Cropp images before saving them to save space:
							run("Clear Results");
      					    title=getTitle;selectWindow(title);nz=nSlices;
      					    run("Set Measurements...", "center redirect=None decimal=4");
      					    run("Properties...", "channels=1 slices=1 frames=1 unit=px pixel_width=1 pixel_height=1 voxel_depth=1");
      					    run("Measure");
								x=getResult("XM",i-1);  //translation vectors
              				    y=getResult("YM",i-1);
               				    if(i==1){x0=x;y0=y;}
              				    sx=x0-x;sy=y0-y;
               				    run("Translate...", "x="+sx+" y="+sy+" slice");
							    run("Measure");              //measures center of gravity in aligned image
      								 x1=getResult("XM",i-1); //translation vectors
      							     y1=getResult("YM",i-1);
         							 //print(x1);
         							 //print(y1);
        							 setTool("rectangle");
									 run("Specify...", "width=350 height=350 x=x1 y=y1 slice=10 constrain centered scaled"); // @users - adjsut width/height if your cells are bigger or smaller 
									 run("Crop");            //crops field of view image to a single cell
               				   		 saveAs("Tiff", inputMasks+core+"_smFISH_cell");	
				}
}
setBatchMode(false);
close();
} 


mainTRITCList = getFileList(outputFISH);          // update list of FISH directory
print(mainTRITCList.length); 
mainMasksList = getFileList(outputFINALsc);       // update list of single cell mask directory
print(mainMasksList.length); 

setBatchMode(true);
for (l=0; l<mainTRITCList.length; l++) {          // for loop to parse multiplier through names in main folder
     if(endsWith(mainTRITCList[l], "/")){         // if the name is a subfolder...
          subDir = outputFISH + mainTRITCList[l]; //directory of l-folder, - one of the inputs of multiplier()
          subDirMasks = outputFINALsc + "/" + mainMasksList[l];
          multiplier(subDir, subDirMasks);
   }
}
setBatchMode(false);
print("Single cell RNA-FISH images successfully created!");
wait(300);
print("Progress 5/6");


///////////// 6) Open single cell RNA-FISH images and convert them into a single stack /////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////


listTRITC = getFileList(outputFINALsc);

function opener(input) {                                                //function that displays single cell FISH images 
	ending = "_smFISH_cell.tif";
	list = getFileList(input);
	for (i = 0; i < list.length; i++){     
	if (endsWith(list[i], ending)){
					core = substring(list[i],0,lengthOf(list[i])-16);   // name ending: "_smFISH_cell.tif"
					open(input + core + ending);
	}
  }
}

for (l=0; l<listTRITC.length; l++) {                                    // for loop to parse through names in main folder
     if(endsWith(listTRITC[l], "/")){                                   // if the name is a subfolder...
     newDir = outputFINALsc + listTRITC[l];
	 opener(newDir);  
     }
}
run("Images to Stack", "name=Stack title=[] use");                     // produces stack from open iamges
imgStack=getTitle();
selectWindow(imgStack);
saveAs("Tiff", outputFISH+"/"+"smFISH_singleCellStack.tif"); 
print("Progress 6/6 - Proceed to ThunderSTORM plugin !");
wait(300);

setBatchMode(true);
macro "Register by Translation"{                                       // chunk responsible for further cropping the stack:
        setBatchMode(true);
        run("Clear Results");
        title=getTitle;selectWindow(title);nz=nSlices;
        run("Set Measurements...", "center redirect=None decimal=4");
        for(i=1;i<=nz;i++){
                selectWindow(title);setSlice(i);    
				run("Properties...", "channels=1 slices=nz frames=1 unit=px pixel_width=1 pixel_height=1 voxel_depth=1"); 
                run("Measure"); 
                 x=getResult("XM",i-1); 
              	 y=getResult("YM",i-1);
                 if(i==1){x0=x;y0=y;}
                 sx=x0-x;sy=y0-y;
                 run("Translate...", "x="+sx+" y="+sy+" slice");
        }
        selectWindow(title);
        setBatchMode("exit and display");
         run("Measure");  
      	 x1=getResult("XM",i-1); 
         y1=getResult("YM",i-1);
         setTool("rectangle");
		 run("Specify...", "width=300 height=300 x=x1 y=y1 slice=10 constrain centered scaled"); // crop final single cell data stack to a following dimensions
		 run("Crop"); 
} 
setBatchMode(false);
	      

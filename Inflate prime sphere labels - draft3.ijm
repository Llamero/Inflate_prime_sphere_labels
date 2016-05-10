close("*");
//All 8-bit primes
primes = newArray(2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97,101,103,107,109,113,127,131,137,139,149,151,157,163,167,173,179,181,191,193,197,199,211,223,227,229,233,239,241,251);
labelDirectory = "E:\\Altan Lab\\Median Filtered Stacks (5x5x5)\\Results\\Edited Labels\\";
primeDirectory = "E:\\Altan Lab\\Median Filtered Stacks (5x5x5)\\Results\\Prime Labels\\";
minDirectory = "E:\\Altan Lab\\Median Filtered Stacks (5x5x5)\\Results\\Optimal Min\\"
labelList = getFileList(labelDirectory);
minList = getFileList(minDirectory);
open("E:\\Altan Lab\\Median Filtered Stacks (5x5x5)\\Measurement Matrix.tif");
getDimensions(stackWidth, stackHeight, stackChannels, stackSlices, stackFrames);
setMinAndMax(0.8, 1.5);
run("In [+]");
run("In [+]");
run("In [+]");
run("In [+]");
run("In [+]");
run("In [+]");
run("In [+]");

setBatchMode(true);

for(a=0; a<labelList.length; a++){
	showProgress(a/labelList.length);

	//Count how many spheres are in the current sample
	selectWindow("Measurement Matrix.tif");
	setSlice(a+1);
	for(b=0; b<stackHeight; b++){
		ID = getPixel(1,b);
		if(ID == 0){
			sphereCount = b;
			b = stackHeight;
		}
	}

	//Draw a new image to store the spheres onto
	//Extract the measurements from the results matrix
	selectWindow("Measurement Matrix.tif");
	setSlice(a+1);
	stackWidth = getPixel(6, 0);
	stackHeight = getPixel(7, 0);
	stackSlices = getPixel(8, 0);
	newImage(labelList[a], "16-bit black", stackWidth, stackHeight, stackSlices);
	run("Add...", "value=1 stack");
	saveAs("Tiff", primeDirectory + labelList[a]);

	//Create a mask to search for whether expanded spheres are outside of raw data mask in the XY plane
	open(minDirectory + minList[a]);
	run("Z Project...", "projection=[Sum Slices]");
	selectWindow("SUM_" + minList[a]);

	//Test both the Li and Yen threshold, and choose whichever is lower
	setAutoThreshold("Li dark");
	getThreshold(Li,dummy);
	setAutoThreshold("Yen dark");
	getThreshold(Yen,dummy);
	if(Li<Yen){
		setAutoThreshold("Li dark");
	}
	close(minList[a]);

	//Exponentially inflate the ellipsoids until they are all touching there nearest neighbor
	expansionFactor = 1;
	keepInflating = 1;
	
	while(keepInflating){
		expansionFactor = expansionFactor*1.01;
		
		//Inflate all non-overlapping spheres, while holding all spheres that are already overlapping constant
		selectWindow("Measurement Matrix.tif");
		for(b=0; b<sphereCount; b++){
			overlap = getPixel(10,b);
			outside = getPixel(11,b);
			if(!overlap && !outside){
				setPixel(9,b,expansionFactor);
			}
		}

		//Create the new prime sphere label stack
		createPrimeSpheres(labelList[a], "Measurement Matrix.tif", a+1, primes, sphereCount);
		
		//Search for any spheres that are overlapping
		searchForOverlap(labelList[a], "Measurement Matrix.tif",primes);

		//Search for any spheres that are outside the raw data mask
		searchForSpheresOutsideMask(labelList[a], "Measurement Matrix.tif", primes, "SUM_" + minList[a]);

		//See if any new overlapping spheres were found, and add these spheres to the master stack
		drawOverlapStack(labelList[a], "Measurement Matrix.tif", expansionFactor, sphereCount, primes);

		//Check whether any more spheres need to be expanded (i.e. are not overlapping with any neighbors)
		selectWindow("Measurement Matrix.tif");
		for(b=0; b<sphereCount; b++){
			overlap = getPixel(10,b);
			outside = getPixel(11,b);
			if(!overlap && !outside){
				b = sphereCount+1;
			}
		}

		//If the end of the search was reached, then all spheres are overlapping an no more expansion is needed
		if(b == sphereCount){
			keepInflating = 0;
			close(labelList[a]);
		}
	}
}	

function searchForSpheresOutsideMask(labels, measurementMatrix, primes, mask){
	
	//Delete all data contained within the mask
	selectWindow(mask);
	run("Create Selection");
	selectWindow(labels);
	run("Restore Selection");
	run("Clear", "stack");
	run("Select None");

	//Create a maximum intensity projection of the cropped label stack to find spheres outside mask
	run("Z Project...", "projection=[Max Intensity]");
	
	//close the labels stack, as it is no longer needed
	close(labels);

	//Get the histogram of the cropped stack
	selectWindow("MAX_" + labels);
	getHistogram(1, croppedHisto, 65536);

	//Close max projection
	close("MAX_" + labels);

	//Look for primes, and record these as spheres that are outside the mask
	for(a=0; a<primes.length; a++){
		if(croppedHisto[primes[a]] > 0){
			selectWindow(measurementMatrix);
			setPixel(11, a, 1);
		}
	}
}

function drawOverlapStack(labels, measurementMatrix, currentFactor, sphereCount, primes){
	open(primeDirectory + labels);

	//Initialize variable to track whether a new sphere was found
	sphereFound = 0;
	
	//Search for any newly overlapping spheres
	for(a=0; a<sphereCount; a++){
		selectWindow(measurementMatrix);
		xCen = getPixel(1, a);
		yCen = getPixel(2, a);
		zCen = getPixel(3, a);
		xyRadius = getPixel(4, a);
		zRadius = getPixel(5, a);
		stackWidth = getPixel(6, a);
		stackHeight = getPixel(7, a);
		stackSlices = getPixel(8, a);
		expansionFactor = getPixel(9,a);
		Overlap = getPixel(10,a);

		//If overlap is 0, then give overlap the value of the outside pixel
		if(!Overlap){
			Overlap = getPixel(11,a);		
		}


		//If the sphere is a newly found overlapping sphere, add it to the master stack
		if(Overlap && round(expansionFactor*100) == round(currentFactor*100)){
			run("3D Draw Shape", "size=" + stackWidth + "," + stackHeight + "," + stackSlices + " center=" + xCen + "," + yCen + "," + zCen + " radius=" + xyRadius*expansionFactor + "," + xyRadius*expansionFactor + "," + zRadius*expansionFactor + " vector1=1.0,0.0,0.0 vector2=0.0,1.0,0.0 res_xy=1.000 res_z=1.000 unit=pix value=" + primes[a]-1 + " display=[New stack]");
			selectWindow("Shape3D");
			run("Add...", "value=1 stack");
			imageCalculator("Multiply stack", labels,"Shape3D");
			close("Shape3D");
			sphereFound = 1;
		}
	}

	//If a new sphere was found, save the new stack
	if(sphereFound){
			selectWindow(labels);
			saveAs("tiff", primeDirectory + labels);
	}
}

function searchForOverlap(labels, measurementMatrix, primes){
	//Build an array with the 16-bit stack histogram
	newImage("Stack Histogram", "16-bit black", 65536, 1, stackSlices);

	//Measure the histogram of each slice and record it
	for(a=1; a<=nSlices; a++){
		selectWindow(labels);
		setSlice(a);
		getHistogram(1, sliceHisto, 65536);
		selectWindow("Stack Histogram");
		setSlice(a);
		for(b=0; b<65536; b++){
			setPixel(b,0,sliceHisto[b]);
		}
	}

	//Create a sum histogram for all slices
	selectWindow("Stack Histogram");
	run("Z Project...", "projection=[Sum Slices]");
	close("Stack Histogram");

	//Clear any single primes in the histogram, as these are non-overlapping
	selectWindow("SUM_Stack Histogram");
	for(a=0; a<primes.length; a++){
		setPixel(primes[a], 0, 0);
	}

	//Remove the intensity 1 was well as this is the background
	setPixel(0,0,0);
	setPixel(1,0,0);

	//Scan the remaining histogram to see if any semiprimes remain
	for(a=0; a<65536; a++){

		//Retrieve the pixel intensity
		pixelCount = getPixel(a,0);

		//If the pixel has an intensity greater than 0, find the prime factors
		if(pixelCount>0){

			//The semiprime is equal to the index position in the histogram (pixel int)
			semiPrime = a;

			//Search through the list of possible primes to find all factors (the ID of all overlapping spheres
			for(b=0; b<primes.length; b++){
				if(semiPrime%primes[b] == 0){
					//Set pixel value for this sphere to one, so that it is no longer expanded
					selectWindow(measurementMatrix);
					setPixel(10,b,1);

					//Remove prime factor from semiprime
					semiPrime = semiPrime/primes[b];

					//Record which sphere each sphere was touching in the measurement matrix
					if(semiPrime > 1){
						for(c=12; c<30; c++){
							recordPixel = getPixel(c,a);
							if(recordPixel == 0){
								setPixel(c,b,semiPrime);
								factor1 = primes[b];
								c=30;	
							}
						}
					}
					else{
						for(c=12; c<30; c++){
							recordPixel = getPixel(c,a);
							if(recordPixel == 0){
								setPixel(c,b,factor1);
								c=30;	
							}
						}
					}
				}
				//If semiprime is 1, then all factors have been found
				if(semiPrime == 1){
					b = primes.length + 1;
				}
			}

			//If the search reaches the end of the list, then the number doesn not have prime factors, which is impossible			
			if(b == primes.length){
				exit("Error: Non prime factor found.");
			}

			//Reset min and max so that the results can be viewed in the measurement matrix
			selectWindow(measurementMatrix);
			setMinAndMax(0.8, 1.5);

			//Leave the select window in the conditional statement, as this speeds up analysis rather than selecting the window with every read.
			selectWindow("SUM_Stack Histogram");
		}
	}
	//Close the histogram image
	close("SUM_Stack Histogram");
}

function createPrimeSpheres(fileName, measurementMatrix, fileNumber, primes, nSphere){
	//Determine the maximum number of spheres
	for(sphereCounter=0; sphereCounter<nSphere; sphereCounter++){
		selectWindow(measurementMatrix);
		labelID = getPixel(1,sphereCounter);
		overlap = getPixel(10,sphereCounter);
		outside = getPixel(11,sphereCounter);
		
		//If there was a sphere measurement at this index and the sphere is not already overlapping, draw the corresponding sphere
		if(labelID > 0 && !overlap && !outside){
			//Extract the measurements from the results matrix
			selectWindow(measurementMatrix);
			setSlice(fileNumber);
			sliceMax = getPixel(0, sphereCounter);
			xCen = getPixel(1, sphereCounter);
			yCen = getPixel(2, sphereCounter);
			zCen = getPixel(3, sphereCounter);
			xyRadius = getPixel(4, sphereCounter);
			zRadius = getPixel(5, sphereCounter);
			stackWidth = getPixel(6, sphereCounter);
			stackHeight = getPixel(7, sphereCounter);
			stackSlices = getPixel(8, sphereCounter);
			expansionFactor = getPixel(9, sphereCounter);
			
			//Draw spheres
			//One is subtracted from the prime and then added to the whole image since the background needs to be one (this is the fastest way to achieve this
			//The background needs to be one since we want the primes to be multiplied (pixels with value 0 clear everything)
			run("3D Draw Shape", "size=" + stackWidth + "," + stackHeight + "," + stackSlices + " center=" + xCen + "," + yCen + "," + zCen + " radius=" + xyRadius*expansionFactor + "," + xyRadius*expansionFactor + "," + zRadius*expansionFactor + " vector1=1.0,0.0,0.0 vector2=0.0,1.0,0.0 res_xy=1.000 res_z=1.000 unit=pix value=" + primes[sphereCounter]-1 + " display=[New stack]");
			selectWindow("Shape3D");
			run("Add...", "value=1 stack");
			imageCalculator("Multiply stack", fileName,"Shape3D");
			close("Shape3D");
		}
	}
}

setBatchMode(false);

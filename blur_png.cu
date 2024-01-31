#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#include "/content/lodepng.h"

const int ERROR_EXIT_VALUE = -1;


__global__
void cudaBlur(unsigned char* originalVals, unsigned char* blurredVals, 
int width, int height) {
  int uid = 300 * blockIdx.x + threadIdx.x;
  
  int pixelX = uid % width;
  int pixelY = uid / width;

  if(pixelY == 0 || pixelY == height-1){
    return;
  }

  int i, sum, up, down;
  int p = 4*uid;
  for(i=0; i<4; i++){
    sum = 0;
    if((i+1)%4 == 0){
      blurredVals[p+i] = originalVals[p+i];
    }else{
      up = ((pixelY-1) * (width) + pixelX) * 4;
      sum+=(originalVals[up+i-4]+originalVals[up+i]+originalVals[up+i+4]);
      sum+= (originalVals[p+i-4]+originalVals[p+i]+originalVals[p+i+4]);
      down = ((pixelY+1) * (width) + pixelX) * 4;
      sum+=(originalVals[down+i-4]+originalVals[down+i]+originalVals[down+i+4]);
      blurredVals[p+i] = sum / 9;
    }
    
  }
}

int main (int argc, char* argv[]) {

	  char* fileName = "/content/5n5PNs3.png";
    if (argc > 1)
        fileName = argv[1];
    
    char* outputFileName = "/content/output.png";
    if (argc > 2)
    	outputFileName = argv[2];

    unsigned int width, height;
    unsigned int lodepng_error;

    unsigned char* cpuImg1DValues = (unsigned char*) malloc( sizeof(unsigned char) * width * height * 4 );
    lodepng_error = lodepng_decode32_file(&cpuImg1DValues, &width, &height, fileName);

    if (lodepng_error) {
      printf("Error decoding png file: '%u' '%s'\n", lodepng_error, lodepng_error_text(lodepng_error));
      exit(ERROR_EXIT_VALUE);
    }

    int imgSize = width * height * 4;  // totalImgPixels

printf ("%d %d %d",width, height, imgSize);

	  if (width <= 0 || height <= 0) {
        printf("Unable to decode image. Validate file and try again\n");
        exit(ERROR_EXIT_VALUE);
    }

    unsigned char* gpuInputImgVals;
    cudaMalloc((void**) &gpuInputImgVals, sizeof(unsigned char) * imgSize);
    cudaMemcpy(gpuInputImgVals, cpuImg1DValues, sizeof(unsigned char) * imgSize, cudaMemcpyHostToDevice);

    unsigned char* gpuOutputImgVals;
    cudaMalloc((void**) &gpuOutputImgVals, sizeof(unsigned char) * imgSize);

    cudaBlur<<<300, 300>>>(gpuInputImgVals, gpuOutputImgVals, width, height);

    unsigned char* cpuOutImg = (unsigned char*) malloc( sizeof(unsigned char) * imgSize );
    cudaMemcpy(cpuOutImg, gpuOutputImgVals, sizeof(unsigned char) * imgSize, cudaMemcpyDeviceToHost);

   	cudaDeviceSynchronize();

    lodepng_error = lodepng_encode32_file(outputFileName, cpuOutImg, width, height);
      
    if (lodepng_error) {
      printf("Error encoding png file: '%u' '%s'\n", lodepng_error, lodepng_error_text(lodepng_error));
      exit(ERROR_EXIT_VALUE);
    }

    free(cpuImg1DValues);
    free(cpuOutImg);
    cudaFree(gpuInputImgVals);
    cudaFree(gpuOutputImgVals);
}
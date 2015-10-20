//
//  ImageQualityAnalyzer.h
//  TBScope
//
//  Created by Frankie Myers on 6/18/14.
//  Copyright (c) 2014 UC Berkeley Fletcher Lab. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "cv.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

typedef struct
    {
        double normalizedGraylevelVariance;
        double varianceOfLaplacian;
        double modifiedLaplacian;
        double tenengrad1;
        double tenengrad3;
        double tenengrad9;
        double movingAverageSharpness;
        double movingAverageContrast;
        double entropy;
        double maxVal;
        double contrast;
        double greenContrast;
    } ImageQuality;

@interface ImageQualityAnalyzer : NSObject

+ (IplImage *)createIplImageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer;

+ (ImageQuality) calculateFocusMetricFromCvMat:(cv::Mat)src;
+ (ImageQuality) calculateFocusMetricFromIplImage:(IplImage *)iplImage;

+ (double) contrastForCvMat:(cv::Mat)src;
+ (double) sharpnessForCvMat:(cv::Mat)src;

+ (UIImage*) maskCircleFromImage:(UIImage*)inputImage;

+ (UIImage *)cropImage:(UIImage*)image withBounds:(CGRect)rect;

@end

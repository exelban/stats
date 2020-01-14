//
//  ColoredLineChartViewController.m
//  ChartsDemo
//
//  Created by Daniel Cohen Gindi on 17/3/15.
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

#import "ColoredLineChartViewController.h"
#import "ChartsDemo-Swift.h"

@interface ColoredLineChartViewController () <ChartViewDelegate>

@property (nonatomic, strong) IBOutletCollection(LineChartView) NSArray *chartViews;

@end

@implementation ColoredLineChartViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Colored Line Chart";
    
    LineChartData *data = [self dataWithCount:36 range:100];
    [data setValueFont:[UIFont fontWithName:@"HelveticaNeue-Light" size:7.f]];
    
    NSArray *colors = @[
                        [UIColor colorWithRed:137/255.f green:230/255.f blue:81/255.f alpha:1.f],
                        [UIColor colorWithRed:240/255.f green:240/255.f blue:30/255.f alpha:1.f],
                        [UIColor colorWithRed:89/255.f green:199/255.f blue:250/255.f alpha:1.f],
                        [UIColor colorWithRed:250/255.f green:104/255.f blue:104/255.f alpha:1.f],
                        ];
    
    for (int i = 0; i < _chartViews.count; i++)
    {
        [self setupChart:_chartViews[i] data:data color:colors[i % colors.count]];
    }
}

- (void)setupChart:(LineChartView *)chart data:(LineChartData *)data color:(UIColor *)color
{
    chart.delegate = self;
    chart.backgroundColor = color;
    
    chart.descriptionText = @"";
    chart.noDataTextDescription = @"You need to provide data for the chart.";
    
    chart.drawGridBackgroundEnabled = NO;
    chart.dragEnabled = YES;
    [chart setScaleEnabled:YES];
    chart.pinchZoomEnabled = NO;
    [chart setViewPortOffsetsWithLeft:10.0 top:0.0 right:10.0 bottom:0.0];
    
    chart.legend.enabled = NO;
    
    chart.leftAxis.enabled = NO;
    chart.rightAxis.enabled = NO;
    chart.xAxis.enabled = NO;
    
    chart.data = data;
    
    [chart animateWithXAxisDuration:2.5];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (LineChartData *)dataWithCount:(int)count range:(double)range
{
    NSMutableArray *xVals = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < count; i++)
    {
        [xVals addObject:[@(i % 12) stringValue]];
    }
    
    NSMutableArray *yVals = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < count; i++)
    {
        double val = (double) (arc4random_uniform(range)) + 3;
        [yVals addObject:[[ChartDataEntry alloc] initWithValue:val xIndex:i]];
    }
    
    LineChartDataSet *set1 = [[LineChartDataSet alloc] initWithYVals:yVals label:@"DataSet 1"];
    
    set1.lineWidth = 1.75;
    set1.circleRadius = 3.0;
    [set1 setColor:UIColor.whiteColor];
    [set1 setCircleColor:UIColor.whiteColor];
    set1.highlightColor = UIColor.whiteColor;
    set1.drawValuesEnabled = NO;
    
    return [[LineChartData alloc] initWithXVals:xVals dataSet:set1];
}

#pragma mark - ChartViewDelegate

- (void)chartValueSelected:(ChartViewBase * __nonnull)chartView entry:(ChartDataEntry * __nonnull)entry dataSetIndex:(NSInteger)dataSetIndex highlight:(ChartHighlight * __nonnull)highlight
{
    NSLog(@"chartValueSelected");
}

- (void)chartValueNothingSelected:(ChartViewBase * __nonnull)chartView
{
    NSLog(@"chartValueNothingSelected");
}

@end

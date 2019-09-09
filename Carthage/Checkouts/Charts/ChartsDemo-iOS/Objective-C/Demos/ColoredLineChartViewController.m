//
//  ColoredLineChartViewController.m
//  ChartsDemo
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

#import "ColoredLineChartViewController.h"
#import "ChartsDemo_iOS-Swift.h"

@interface ColoredLineChartViewController () <ChartViewDelegate>

@property (nonatomic, strong) IBOutletCollection(LineChartView) NSArray *chartViews;

@end

@implementation ColoredLineChartViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Colored Line Chart";
    
    for (int i = 0; i < _chartViews.count; i++)
    {
        LineChartData *data = [self dataWithCount:36 range:100];
        [data setValueFont:[UIFont fontWithName:@"HelveticaNeue-Light" size:7.f]];
        
        NSArray *colors = @[
                            [UIColor colorWithRed:137/255.f green:230/255.f blue:81/255.f alpha:1.f],
                            [UIColor colorWithRed:240/255.f green:240/255.f blue:30/255.f alpha:1.f],
                            [UIColor colorWithRed:89/255.f green:199/255.f blue:250/255.f alpha:1.f],
                            [UIColor colorWithRed:250/255.f green:104/255.f blue:104/255.f alpha:1.f],
                            ];
        
        [self setupChart:_chartViews[i] data:data color:colors[i % colors.count]];
    }
}

- (void)setupChart:(LineChartView *)chart data:(LineChartData *)data color:(UIColor *)color
{
    [(LineChartDataSet *)[data getDataSetByIndex:0] setCircleHoleColor:color];

    chart.delegate = self;
    chart.backgroundColor = color;
    
    chart.chartDescription.enabled = NO;
    
    chart.drawGridBackgroundEnabled = NO;
    chart.dragEnabled = YES;
    [chart setScaleEnabled:YES];
    chart.pinchZoomEnabled = NO;
    [chart setViewPortOffsetsWithLeft:10.0 top:0.0 right:10.0 bottom:0.0];
    
    chart.legend.enabled = NO;
    
    chart.leftAxis.enabled = NO;
    chart.leftAxis.spaceTop = 0.4;
    chart.leftAxis.spaceBottom = 0.4;
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
    NSMutableArray *yVals = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < count; i++)
    {
        double val = (double) (arc4random_uniform(range)) + 3;
        [yVals addObject:[[ChartDataEntry alloc] initWithX:i y:val]];
    }
    
    LineChartDataSet *set1 = [[LineChartDataSet alloc] initWithEntries:yVals label:@"DataSet 1"];
    
    set1.lineWidth = 1.75;
    set1.circleRadius = 5.0;
    set1.circleHoleRadius = 2.5f;
    [set1 setColor:UIColor.whiteColor];
    [set1 setCircleColor:UIColor.whiteColor];
    set1.highlightColor = UIColor.whiteColor;
    set1.drawValuesEnabled = NO;
    
    return [[LineChartData alloc] initWithDataSet:set1];
}

#pragma mark - ChartViewDelegate

- (void)chartValueSelected:(ChartViewBase * __nonnull)chartView entry:(ChartDataEntry * __nonnull)entry highlight:(ChartHighlight * __nonnull)highlight
{
    NSLog(@"chartValueSelected");
}

- (void)chartValueNothingSelected:(ChartViewBase * __nonnull)chartView
{
    NSLog(@"chartValueNothingSelected");
}

@end

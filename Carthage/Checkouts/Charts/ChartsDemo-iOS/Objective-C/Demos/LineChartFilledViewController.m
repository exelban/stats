//
//  LineChartFilledViewController.m
//  ChartsDemo
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

#import "LineChartFilledViewController.h"
#import "ChartsDemo_iOS-Swift.h"

@interface LineChartFilledViewController () <ChartViewDelegate>

@property (nonatomic, strong) IBOutlet LineChartView *chartView;
@property (nonatomic, strong) IBOutlet UISlider *sliderX;
@property (nonatomic, strong) IBOutlet UISlider *sliderY;
@property (nonatomic, strong) IBOutlet UITextField *sliderTextX;
@property (nonatomic, strong) IBOutlet UITextField *sliderTextY;

@end

@implementation LineChartFilledViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Filled Line Chart";
    
    _chartView.delegate = self;
    
    _chartView.backgroundColor = UIColor.whiteColor;
    _chartView.gridBackgroundColor = [UIColor colorWithRed:51/255.0 green:181/255.0 blue:229/255.0 alpha:150/255.0];
    _chartView.drawGridBackgroundEnabled = YES;
    
    _chartView.drawBordersEnabled = YES;
    
    _chartView.chartDescription.enabled = NO;
    
    _chartView.pinchZoomEnabled = NO;
    _chartView.dragEnabled = YES;
    [_chartView setScaleEnabled:YES];
    
    ChartLegend *l = _chartView.legend;
    l.enabled = NO;
    
    ChartXAxis *xAxis = _chartView.xAxis;
    xAxis.enabled = NO;
    
    ChartYAxis *leftAxis = _chartView.leftAxis;
    leftAxis.axisMaximum = 900.0;
    leftAxis.axisMinimum = -250.0;
    leftAxis.drawAxisLineEnabled = NO;
    leftAxis.drawZeroLineEnabled = NO;
    leftAxis.drawGridLinesEnabled = NO;
    
    _chartView.rightAxis.enabled = NO;
    
    _sliderX.value = 100.0;
    _sliderY.value = 60.0;
    [self slidersValueChanged:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)updateChartData
{
    if (self.shouldHideData)
    {
        _chartView.data = nil;
        return;
    }
    
    [self setDataCount:_sliderX.value range:_sliderY.value];
}

- (void)setDataCount:(int)count range:(double)range
{
    NSMutableArray *yVals1 = [NSMutableArray array];
    NSMutableArray *yVals2 = [NSMutableArray array];
    
    for (int i = 0; i < count; i++)
    {
        double val = arc4random_uniform(range) + 50;
        [yVals1 addObject:[[ChartDataEntry alloc] initWithX:i y:val]];
    }
    
    for (int i = 0; i < count; i++)
    {
        double val = arc4random_uniform(range) + 450;
        [yVals2 addObject:[[ChartDataEntry alloc] initWithX:i y:val]];
    }
    
    LineChartDataSet *set1 = nil;
    LineChartDataSet *set2 = nil;
    
    if (_chartView.data.dataSetCount > 0)
    {
        set1 = (LineChartDataSet *)_chartView.data.dataSets[0];
        set2 = (LineChartDataSet *)_chartView.data.dataSets[1];
        [set1 replaceEntries:yVals1];
        [set2 replaceEntries:yVals2];
        [_chartView.data notifyDataChanged];
        [_chartView notifyDataSetChanged];
    }
    else
    {
        set1 = [[LineChartDataSet alloc] initWithEntries:yVals1 label:@"DataSet 1"];
        set1.axisDependency = AxisDependencyLeft;
        [set1 setColor:[UIColor colorWithRed:255/255.0 green:241/255.0 blue:46/255.0 alpha:1.0]];
        set1.drawCirclesEnabled = NO;
        set1.lineWidth = 2.0;
        set1.circleRadius = 3.0;
        set1.fillAlpha = 1.0;
        set1.drawFilledEnabled = YES;
        set1.fillColor = UIColor.whiteColor;
        set1.highlightColor = [UIColor colorWithRed:244/255.0 green:117/255.0 blue:117/255.0 alpha:1.0];
        set1.drawCircleHoleEnabled = NO;
        set1.fillFormatter = [ChartDefaultFillFormatter withBlock:^CGFloat(id<ILineChartDataSet>  _Nonnull dataSet, id<LineChartDataProvider>  _Nonnull dataProvider) {
            return self.chartView.leftAxis.axisMinimum;
        }];
        
        set2 = [[LineChartDataSet alloc] initWithEntries:yVals2 label:@"DataSet 2"];
        set2.axisDependency = AxisDependencyLeft;
        [set2 setColor:[UIColor colorWithRed:255/255.0 green:241/255.0 blue:46/255.0 alpha:1.0]];
        set2.drawCirclesEnabled = NO;
        set2.lineWidth = 2.0;
        set2.circleRadius = 3.0;
        set2.fillAlpha = 1.0;
        set2.drawFilledEnabled = YES;
        set2.fillColor = UIColor.whiteColor;
        set2.highlightColor = [UIColor colorWithRed:244/255.0 green:117/255.0 blue:117/255.0 alpha:1.0];
        set2.drawCircleHoleEnabled = NO;
        set2.fillFormatter = [ChartDefaultFillFormatter withBlock:^CGFloat(id<ILineChartDataSet>  _Nonnull dataSet, id<LineChartDataProvider>  _Nonnull dataProvider) {
            return self.chartView.leftAxis.axisMaximum;
        }];
        
        NSMutableArray *dataSets = [[NSMutableArray alloc] init];
        [dataSets addObject:set1];
        [dataSets addObject:set2];
        
        LineChartData *data = [[LineChartData alloc] initWithDataSets:dataSets];
        [data setDrawValues:NO];
        
        _chartView.data = data;
    }
}

#pragma mark - Actions

- (IBAction)slidersValueChanged:(id)sender
{
    _sliderTextX.text = [@((int)_sliderX.value) stringValue];
    _sliderTextY.text = [@((int)_sliderY.value) stringValue];
    
    [self updateChartData];
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

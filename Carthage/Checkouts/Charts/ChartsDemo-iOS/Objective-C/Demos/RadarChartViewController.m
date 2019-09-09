//
//  RadarChartViewController.m
//  ChartsDemo
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

#import "RadarChartViewController.h"
#import "ChartsDemo_iOS-Swift.h"

@interface RadarChartViewController () <ChartViewDelegate, IChartAxisValueFormatter>

@property (nonatomic, strong) IBOutlet RadarChartView *chartView;
@property (nonatomic, strong) NSArray<NSString *> *activities;
@property (nonatomic, strong) UIColor *originalBarBgColor;
@property (nonatomic, strong) UIColor *originalBarTintColor;
@property (nonatomic) UIBarStyle originalBarStyle;

@end

@implementation RadarChartViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.activities = @[ @"Burger", @"Steak", @"Salad", @"Pasta", @"Pizza" ];
    
    self.title = @"Radar Chart";
    
    self.options = @[
                     @{@"key": @"toggleValues", @"label": @"Toggle Values"},
                     @{@"key": @"toggleHighlight", @"label": @"Toggle Highlight"},
                     @{@"key": @"toggleHighlightCircle", @"label": @"Toggle highlight circle"},
                     @{@"key": @"toggleXLabels", @"label": @"Toggle X-Values"},
                     @{@"key": @"toggleYLabels", @"label": @"Toggle Y-Values"},
                     @{@"key": @"toggleRotate", @"label": @"Toggle Rotate"},
                     @{@"key": @"toggleFill", @"label": @"Toggle Fill"},
                     @{@"key": @"animateX", @"label": @"Animate X"},
                     @{@"key": @"animateY", @"label": @"Animate Y"},
                     @{@"key": @"animateXY", @"label": @"Animate XY"},
                     @{@"key": @"spin", @"label": @"Spin"},
                     @{@"key": @"saveToGallery", @"label": @"Save to Camera Roll"},
                     @{@"key": @"toggleData", @"label": @"Toggle Data"},
                     ];
    
    _chartView.delegate = self;
    
    _chartView.chartDescription.enabled = NO;
    _chartView.webLineWidth = 1.0;
    _chartView.innerWebLineWidth = 1.0;
    _chartView.webColor = UIColor.lightGrayColor;
    _chartView.innerWebColor = UIColor.lightGrayColor;
    _chartView.webAlpha = 1.0;
    
    RadarMarkerView *marker = (RadarMarkerView *)[RadarMarkerView viewFromXibIn:[NSBundle mainBundle]];
    marker.chartView = _chartView;
    _chartView.marker = marker;
    
    ChartXAxis *xAxis = _chartView.xAxis;
    xAxis.labelFont = [UIFont fontWithName:@"HelveticaNeue-Light" size:9.f];
    xAxis.xOffset = 0.0;
    xAxis.yOffset = 0.0;
    xAxis.valueFormatter = self;
    xAxis.labelTextColor = UIColor.whiteColor;
    
    ChartYAxis *yAxis = _chartView.yAxis;
    yAxis.labelFont = [UIFont fontWithName:@"HelveticaNeue-Light" size:9.f];
    yAxis.labelCount = 5;
    yAxis.axisMinimum = 0.0;
    yAxis.axisMaximum = 80.0;
    yAxis.drawLabelsEnabled = NO;
    
    ChartLegend *l = _chartView.legend;
    l.horizontalAlignment = ChartLegendHorizontalAlignmentCenter;
    l.verticalAlignment = ChartLegendVerticalAlignmentTop;
    l.orientation = ChartLegendOrientationHorizontal;
    l.drawInside = NO;
    l.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:10.f];
    l.xEntrySpace = 7.0;
    l.yEntrySpace = 5.0;
    l.textColor = UIColor.whiteColor;
    
    [self updateChartData];
    
    [_chartView animateWithXAxisDuration:1.4 yAxisDuration:1.4 easingOption:ChartEasingOptionEaseOutBack];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [UIView animateWithDuration:0.15 animations:^{
        UINavigationBar *navigationBar = self.navigationController.navigationBar;
        self.originalBarBgColor = navigationBar.barTintColor;
        self.originalBarTintColor = navigationBar.tintColor;
        self.originalBarStyle = navigationBar.barStyle;
        
        navigationBar.barTintColor = self.view.backgroundColor;
        navigationBar.tintColor = UIColor.whiteColor;
        navigationBar.barStyle = UIBarStyleBlack;
    }];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [UIView animateWithDuration:0.15 animations:^{
        UINavigationBar *navigationBar = self.navigationController.navigationBar;
        navigationBar.barTintColor = self.originalBarBgColor;
        navigationBar.tintColor = self.originalBarTintColor;
        navigationBar.barStyle = self.originalBarStyle;
    }];
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
    
    [self setChartData];
}

- (void)setChartData
{
    double mult = 80;
    double min = 20;
    int cnt = 5;
    
    NSMutableArray *entries1 = [[NSMutableArray alloc] init];
    NSMutableArray *entries2 = [[NSMutableArray alloc] init];
    
    // NOTE: The order of the entries when being added to the entries array determines their position around the center of the chart.
    for (int i = 0; i < cnt; i++)
    {
        [entries1 addObject:[[RadarChartDataEntry alloc] initWithValue:(arc4random_uniform(mult) + min)]];
        [entries2 addObject:[[RadarChartDataEntry alloc] initWithValue:(arc4random_uniform(mult) + min)]];
    }
    
    RadarChartDataSet *set1 = [[RadarChartDataSet alloc] initWithEntries:entries1 label:@"Last Week"];
    [set1 setColor:[UIColor colorWithRed:103/255.0 green:110/255.0 blue:129/255.0 alpha:1.0]];
    set1.fillColor = [UIColor colorWithRed:103/255.0 green:110/255.0 blue:129/255.0 alpha:1.0];
    set1.drawFilledEnabled = YES;
    set1.fillAlpha = 0.7;
    set1.lineWidth = 2.0;
    set1.drawHighlightCircleEnabled = YES;
    [set1 setDrawHighlightIndicators:NO];

    RadarChartDataSet *set2 = [[RadarChartDataSet alloc] initWithEntries:entries2 label:@"This Week"];
    [set2 setColor:[UIColor colorWithRed:121/255.0 green:162/255.0 blue:175/255.0 alpha:1.0]];
    set2.fillColor = [UIColor colorWithRed:121/255.0 green:162/255.0 blue:175/255.0 alpha:1.0];
    set2.drawFilledEnabled = YES;
    set2.fillAlpha = 0.7;
    set2.lineWidth = 2.0;
    set2.drawHighlightCircleEnabled = YES;
    [set2 setDrawHighlightIndicators:NO];
    
    RadarChartData *data = [[RadarChartData alloc] initWithDataSets:@[set1, set2]];
    [data setValueFont:[UIFont fontWithName:@"HelveticaNeue-Light" size:8.f]];
    [data setDrawValues:NO];
    data.valueTextColor = UIColor.whiteColor;
    
    _chartView.data = data;
}

- (void)optionTapped:(NSString *)key
{
    if ([key isEqualToString:@"toggleXLabels"])
    {
        _chartView.xAxis.drawLabelsEnabled = !_chartView.xAxis.isDrawLabelsEnabled;
        
        [_chartView.data notifyDataChanged];
        [_chartView notifyDataSetChanged];
        [_chartView setNeedsDisplay];
        return;
    }
    
    if ([key isEqualToString:@"toggleYLabels"])
    {
        _chartView.yAxis.drawLabelsEnabled = !_chartView.yAxis.isDrawLabelsEnabled;
        [_chartView setNeedsDisplay];
        return;
    }

    if ([key isEqualToString:@"toggleRotate"])
    {
        _chartView.rotationEnabled = !_chartView.isRotationEnabled;
        return;
    }
    
    if ([key isEqualToString:@"toggleFill"])
    {
        for (RadarChartDataSet *set in _chartView.data.dataSets)
        {
            set.drawFilledEnabled = !set.isDrawFilledEnabled;
        }
        
        [_chartView setNeedsDisplay];
        return;
    }
    
    if ([key isEqualToString:@"toggleHighlightCircle"])
    {
        for (RadarChartDataSet *set in _chartView.data.dataSets)
        {
            set.drawHighlightCircleEnabled = !set.drawHighlightCircleEnabled;
        }
        
        [_chartView setNeedsDisplay];
        return;
    }
    
    if ([key isEqualToString:@"animateX"])
    {
        [_chartView animateWithXAxisDuration:1.4];
        return;
    }
    
    if ([key isEqualToString:@"animateY"])
    {
        [_chartView animateWithYAxisDuration:1.4];
        return;
    }
    
    if ([key isEqualToString:@"animateXY"])
    {
        [_chartView animateWithXAxisDuration:1.4 yAxisDuration:1.4];
        return;
    }
    
    if ([key isEqualToString:@"spin"])
    {
        [_chartView spinWithDuration:2.0 fromAngle:_chartView.rotationAngle toAngle:_chartView.rotationAngle + 360.f easingOption:ChartEasingOptionEaseInCubic];
        return;
    }
    
    [super handleOption:key forChartView:_chartView];
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

#pragma mark - IAxisValueFormatter

- (NSString *)stringForValue:(double)value
                        axis:(ChartAxisBase *)axis
{
    return self.activities[(int) value % self.activities.count];
}

@end

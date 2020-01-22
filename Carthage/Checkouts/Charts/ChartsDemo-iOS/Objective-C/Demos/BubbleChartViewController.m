//
//  BubbleChartViewController.m
//  ChartsDemo
//
//  Bubble chart implementation:
//    Copyright 2015 Pierre-Marc Airoldi
//    Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

#import "BubbleChartViewController.h"
#import "ChartsDemo_iOS-Swift.h"

@interface BubbleChartViewController () <ChartViewDelegate>

@property (nonatomic, strong) IBOutlet BubbleChartView *chartView;
@property (nonatomic, strong) IBOutlet UISlider *sliderX;
@property (nonatomic, strong) IBOutlet UISlider *sliderY;
@property (nonatomic, strong) IBOutlet UITextField *sliderTextX;
@property (nonatomic, strong) IBOutlet UITextField *sliderTextY;

@end

@implementation BubbleChartViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Bubble Chart";
    
    self.options = @[
                     @{@"key": @"toggleValues", @"label": @"Toggle Values"},
                     @{@"key": @"toggleIcons", @"label": @"Toggle Icons"},
                     @{@"key": @"toggleHighlight", @"label": @"Toggle Highlight"},
                     @{@"key": @"animateX", @"label": @"Animate X"},
                     @{@"key": @"animateY", @"label": @"Animate Y"},
                     @{@"key": @"animateXY", @"label": @"Animate XY"},
                     @{@"key": @"saveToGallery", @"label": @"Save to Camera Roll"},
                     @{@"key": @"togglePinchZoom", @"label": @"Toggle PinchZoom"},
                     @{@"key": @"toggleAutoScaleMinMax", @"label": @"Toggle auto scale min/max"},
                     @{@"key": @"toggleData", @"label": @"Toggle Data"},
                     ];
    
    _chartView.delegate = self;
    
    _chartView.chartDescription.enabled = NO;
    
    _chartView.drawGridBackgroundEnabled = NO;
    _chartView.dragEnabled = YES;
    [_chartView setScaleEnabled:YES];
    _chartView.maxVisibleCount = 200;
    _chartView.pinchZoomEnabled = YES;
    
    ChartLegend *l = _chartView.legend;
    l.horizontalAlignment = ChartLegendHorizontalAlignmentRight;
    l.verticalAlignment = ChartLegendVerticalAlignmentTop;
    l.orientation = ChartLegendOrientationVertical;
    l.drawInside = NO;
    l.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:10.f];
    
    ChartYAxis *yl = _chartView.leftAxis;
    yl.labelFont = [UIFont fontWithName:@"HelveticaNeue-Light" size:10.f];
    yl.spaceTop = 0.3;
    yl.spaceBottom = 0.3;
    yl.axisMinimum = 0.0; // this replaces startAtZero = YES

    _chartView.rightAxis.enabled = NO;
    
    ChartXAxis *xl = _chartView.xAxis;
    xl.labelPosition = XAxisLabelPositionBottom;
    xl.labelFont = [UIFont fontWithName:@"HelveticaNeue-Light" size:10.f];
    
    _sliderX.value = 10.0;
    _sliderY.value = 50.0;
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
    NSMutableArray *yVals1 = [[NSMutableArray alloc] init];
    NSMutableArray *yVals2 = [[NSMutableArray alloc] init];
    NSMutableArray *yVals3 = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < count; i++)
    {
        double val = (double) (arc4random_uniform(range));
        double size = (double) (arc4random_uniform(range));
        [yVals1 addObject:[[BubbleChartDataEntry alloc] initWithX:i y:val size:size icon: [UIImage imageNamed:@"icon"]]];
        
        val = (double) (arc4random_uniform(range));
        size = (double) (arc4random_uniform(range));
        [yVals2 addObject:[[BubbleChartDataEntry alloc] initWithX:i y:val size:size icon: [UIImage imageNamed:@"icon"]]];
        
        val = (double) (arc4random_uniform(range));
        size = (double) (arc4random_uniform(range));
        [yVals3 addObject:[[BubbleChartDataEntry alloc] initWithX:i y:val size:size]];
    }
    
    BubbleChartDataSet *set1 = [[BubbleChartDataSet alloc] initWithEntries:yVals1 label:@"DS 1"];
    set1.drawIconsEnabled = NO;
    [set1 setColor:ChartColorTemplates.colorful[0] alpha:0.50f];
    [set1 setDrawValuesEnabled:YES];
    
    BubbleChartDataSet *set2 = [[BubbleChartDataSet alloc] initWithEntries:yVals2 label:@"DS 2"];
    set2.iconsOffset = CGPointMake(0, 15);
    [set2 setColor:ChartColorTemplates.colorful[1] alpha:0.50f];
    [set2 setDrawValuesEnabled:YES];
    
    BubbleChartDataSet *set3 = [[BubbleChartDataSet alloc] initWithEntries:yVals3 label:@"DS 3"];
    [set3 setColor:ChartColorTemplates.colorful[2] alpha:0.50f];
    [set3 setDrawValuesEnabled:YES];
    
    NSMutableArray *dataSets = [[NSMutableArray alloc] init];
    [dataSets addObject:set1];
    [dataSets addObject:set2];
    [dataSets addObject:set3];
    
    BubbleChartData *data = [[BubbleChartData alloc] initWithDataSets:dataSets];
    [data setDrawValues:NO];
    [data setValueFont:[UIFont fontWithName:@"HelveticaNeue-Light" size:7.f]];
    [data setHighlightCircleWidth: 1.5];
    [data setValueTextColor:UIColor.whiteColor];
    
    _chartView.data = data;
}

- (void)optionTapped:(NSString *)key
{
    [super handleOption:key forChartView:_chartView];
}

#pragma mark - Actions

- (IBAction)slidersValueChanged:(id)sender
{
    _sliderTextX.text = [@((int)_sliderX.value) stringValue];
    _sliderTextY.text = [@((int)_sliderY.value) stringValue];
    
    [self updateChartData];
}

#pragma mark - ChartViewDelegate

- (void)chartValueSelected:(ChartViewBase * __nonnull)chartView entry:(ChartDataEntry * __nonnull )entry dataSetIndex:(NSInteger)dataSetIndex highlight:(ChartHighlight * __nonnull)highlight
{
    NSLog(@"chartValueSelected");
}

- (void)chartValueNothingSelected:(ChartViewBase * __nonnull)chartView
{
    NSLog(@"chartValueNothingSelected");
}

@end

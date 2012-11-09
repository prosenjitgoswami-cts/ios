//
//  NewMapViewController.m
//  CycleStreets
//
//  Created by Neil Edwards on 26/09/2012.
//  Copyright (c) 2012 CycleStreets Ltd. All rights reserved.
//

#import "NewMapViewController.h"
#import "GlobalUtilities.h"
#import "RMMapView.h"
#import "RoutePlanMenuViewController.h"
#import "ExpandedUILabel.h"
#import "MapMarkerTouchView.h"
#import "CSPointVO.h"
#import "SegmentVO.h"
#import "SettingsManager.h"

#import "RMMapLayer.h"
#import "RMMarker.h"
#import "RMMarkerManager.h"
#import "CycleStreets.h"
#import "AppDelegate.h"
#import "RMOpenStreetMapSource.h"
#import "RMOpenCycleMapSource.h"
#import "RMOrdnanceSurveyStreetViewMapSource.h"
#import "RMTileSource.h"
#import "RMCachedTileSource.h"
#import "PhotoMapListVO.h"
#import "PhotoMapVO.h"
#import "Markers.h"
#import "MapLocationSearchViewController.h"
#import "RMMapView.h"
#import "CSPointVO.h"
#import "RMMercatorToScreenProjection.h"
#import "Files.h"
#import "InitialLocation.h"
#import "RouteManager.h"
#import "GlobalUtilities.h"
#import "AppConstants.h"
#import "SettingsManager.h"
#import "POIListviewController.h"
#import "HudManager.h"
#import "UserLocationManager.h"
#import	"WayPointVO.h"
#import "IIViewDeckController.h"
#import "WayPointViewController.h"


static NSInteger MAX_ZOOM = 18;

static NSInteger MAX_ZOOM_LOCATION = 16;
static NSInteger MAX_ZOOM_LOCATION_ACCURACY = 200;

static NSTimeInterval ACCIDENTAL_TAP_DELAY = 0.5;

//don't allow co-location of start/finish
static CLLocationDistance MIN_START_FINISH_DISTANCE = 100;

static NSString *const LOCATIONSUBSCRIBERID=@"MapView";


@interface MarkerMenuItem : UIMenuItem
@property (nonatomic, strong) WayPointVO* waypoint;
@end



@interface NewMapViewController()

// tool bar
@property (nonatomic, strong) IBOutlet UIToolbar					* toolBar;
@property (nonatomic, strong) UIBarButtonItem						* locationButton;
@property (nonatomic, strong) UIBarButtonItem						* activeLocationButton;
@property (nonatomic, strong) UIBarButtonItem						* searchButton;
@property (nonatomic, strong) UIBarButtonItem						* routeButton;
@property (nonatomic, strong) UIBarButtonItem						* changePlanButton;
@property (nonatomic, strong) UIActivityIndicatorView				* locatingIndicator;
@property (nonatomic, strong) UIBarButtonItem						* leftFlex;
@property (nonatomic, strong) UIBarButtonItem						* rightFlex;
@property(nonatomic,strong)  UIBarButtonItem						* waypointButton;




//rmmap
@property (nonatomic, strong) IBOutlet RMMapView		* mapView;
@property (nonatomic, strong) RMMapContents		* mapContents;
@property (nonatomic, strong) CLLocation		* lastLocation;

// sub views
@property (nonatomic, strong) RoutePlanMenuViewController		* routeplanView;
@property (nonatomic, strong) WEPopoverController		* routeplanMenu;
@property (nonatomic, strong) MapLocationSearchViewController		* mapLocationSearchView;

// ui
@property (nonatomic, strong) IBOutlet UILabel		* attributionLabel;
@property (nonatomic, strong) IBOutlet RouteLineView		* lineView;
@property (nonatomic, strong) IBOutlet BlueCircleView		* blueCircleView;
@property (nonatomic, strong) IBOutlet MapMarkerTouchView		* markerTouchView;
@property (nonatomic, assign) MapAlertType		alertType;

// waypoint ui
// will need ui for editing waypoints
@property(nonatomic,assign)  BOOL						markerMenuOpen;


@property (nonatomic, strong) InitialLocation		* initialLocation; // deprecate

// data
@property (nonatomic, strong) RouteVO				* route;
@property (nonatomic, strong) NSMutableArray		* waypointArray;
@property (nonatomic, strong) RMMarker				* activeMarker;

// state
@property (nonatomic, assign) BOOL					doingLocation;
@property (nonatomic, assign) BOOL					programmaticChange;
@property (nonatomic, assign) BOOL					avoidAccidentalTaps;
@property (nonatomic, assign) BOOL					singleTapDidOccur;
@property (nonatomic, assign) CGPoint				singleTapPoint;
@property (nonatomic, assign) MapPlanningState		uiState;
@property (nonatomic, assign) MapPlanningState		previousUIState;


// ui
- (void)initToolBarEntries;
- (void)updateUItoState:(MapPlanningState)state;


// waypoints
-(void)resetWayPoints;
-(void)removeWayPointAtIndex:(int)index;
-(void)assessWayPointAddition:(CLLocationCoordinate2D)cooordinate;
-(void)addWayPointAtCoordinate:(CLLocationCoordinate2D)coords;

// waypoint menu
-(void)removeMarkerAtIndexViaMenu:(UIMenuController*)menuController;

@end



@implementation NewMapViewController


-(void)listNotificationInterests{
	
	
	[notifications addObject:CSMAPSTYLECHANGED];
	[notifications addObject:CSROUTESELECTED];
	[notifications addObject:EVENTMAPROUTEPLAN];
	[notifications addObject:CSLASTLOCATIONLOAD];
	
	[notifications addObject:GPSLOCATIONCOMPLETE];
	[notifications addObject:GPSLOCATIONUPDATE];
	[notifications addObject:GPSLOCATIONFAILED];
	
	
	[super listNotificationInterests];
	
}

-(void)didReceiveNotification:(NSNotification*)notification{
	
	[super didReceiveNotification:notification];
	
	//NSDictionary	*dict=[notification userInfo];
	NSString		*name=notification.name;
	
	if([[UserLocationManager sharedInstance] hasSubscriber:LOCATIONSUBSCRIBERID]){
		
		
		
	}

	if([name isEqualToString:CSMAPSTYLECHANGED]){
		[self didNotificationMapStyleChanged];
	}
	
}

#pragma mark notification response methods


- (void) didNotificationMapStyleChanged {
	self.mapView.contents.tileSource = [NewMapViewController tileSource];
	_attributionLabel.text = [NewMapViewController mapAttribution];
}



//------------------------------------------------------------------------------------
#pragma mark - View methods
//------------------------------------------------------------------------------------
//
/***********************************************
 * @description			View Methods
 ***********************************************/
//

-(void)viewDidLoad{
	
	[super viewDidLoad];
	
	[self createPersistentUI];
	
}


-(void)viewDidAppear:(BOOL)animated{
	
	[self createNonPersistentUI];
	
	[super viewWillAppear:animated];
	
}


-(void)createPersistentUI{
	
	popoverClass = [WEPopoverController class];
	
	
	[self initToolBarEntries];
	
	
	//Necessary to start route-me service
	[RMMapView class];
	
	//
	self.mapContents=[[RMMapContents alloc] initWithView:_mapView tilesource:[NewMapViewController tileSource]];
	
	
	// Initialize
	[_mapView setDelegate:self];
	
	if (self.initialLocation == nil) {
		self.initialLocation = [[InitialLocation alloc] initWithMapView:_mapView withController:self];
	}
	[_initialLocation performSelector:@selector(initiateLocation) withObject:nil afterDelay:0.0];
	
	
	[self resetWayPoints];
	
	[_lineView setPointListProvider:self];
	[_blueCircleView setLocationProvider:self];
	
	
	self.programmaticChange = NO;
	self.singleTapDidOccur=NO;
	
	_attributionLabel.text = [NewMapViewController mapAttribution];
	
	[self updateUItoState:MapPlanningStateNoRoute];
	
	
	[[RouteManager sharedInstance] loadSavedSelectedRoute];

	
}


-(void)createNonPersistentUI{
	
	
	
	
	
}


-(void)initToolBarEntries{
	
	self.locatingIndicator=[[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
	_locatingIndicator.hidesWhenStopped=YES;
	
	self.activeLocationButton = [[UIBarButtonItem alloc] initWithCustomView:_locatingIndicator ];
	_activeLocationButton.style	= UIBarButtonItemStyleDone;
	
	self.waypointButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"CSBarButton_waypoint.png"]
														   style:UIBarButtonItemStyleBordered
														  target:self
														  action:@selector(showWayPointView)];
	_waypointButton.width = 40;
	
	self.locationButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"CSBarButton_location.png"]
														   style:UIBarButtonItemStyleBordered
														  target:self
														  action:@selector(didLocation)];
	_locationButton.width = 40;
	
	self.searchButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"CSBarButton_search.png"]
													   style:UIBarButtonItemStyleBordered
													  target:self
													  action:@selector(didSearch)];
	_searchButton.width = 40;
	
	self.changePlanButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"CSBarButton_routePlan.png"]
													   style:UIBarButtonItemStyleBordered
													  target:self
													  action:@selector(showRoutePlanMenu:)];
	
	
	self.routeButton = [[UIBarButtonItem alloc] initWithTitle:@"Plan Route"
														style:UIBarButtonItemStyleBordered
													   target:self
													   action:@selector(didRoute)];
	
	
	
	self.leftFlex=[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	self.rightFlex=[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	
	
}


//------------------------------------------------------------------------------------
#pragma mark - UI State
//------------------------------------------------------------------------------------
//
/***********************************************
 * @description			State Update
 ***********************************************/
//

-(void)updateUIState{
	[self updateUItoState:_uiState];
}

- (void)updateUItoState:(MapPlanningState)state{
	
	self.previousUIState=_uiState;
	self.uiState = state;
	
	NSArray *items=nil;
	
	switch (_uiState) {
			
		case MapPlanningStateNoRoute:
		{
			BetterLog(@"MapPlanningStateNoRoute");
			
			_searchButton.enabled = YES;
			
			items=@[_locationButton,_searchButton, _leftFlex, _rightFlex];
			[self.toolBar setItems:items animated:YES ];
			
		}
		break;
		
		case MapPlanningStateLocating:
		{
			BetterLog(@"MapPlanningStateLocating");
			
			_searchButton.enabled = YES;
			
			items=@[_waypointButton,_locationButton,_searchButton, _leftFlex, _rightFlex];
			[self.toolBar setItems:items animated:YES ];
			
			
			
		}
		break;
		
		case MapPlanningStateStartPlanning:
		{
			BetterLog(@"MapPlanningStateStartPlanning");
			
			_routeButton.title = @"Plan route";
			_routeButton.style = UIBarButtonItemStyleDone;
			_searchButton.enabled = NO;
			
			items=[@[_locationButton,_searchButton,_leftFlex]mutableCopy];
            
            [self.toolBar setItems:items animated:YES ];
		}
		break;
		
		case MapPlanningStatePlanning:
		{
			BetterLog(@"MapPlanningStatePlanning");
			
			_routeButton.title = @"Plan route";
			_routeButton.style = UIBarButtonItemStyleDone;
			_searchButton.enabled = NO;
			
			items=@[_waypointButton, _locationButton,_searchButton,_leftFlex,_routeButton];
            [self.toolBar setItems:items animated:YES ];
		}
		break;
			
		case MapPlanningStateRoute:
		{
			BetterLog(@"MapPlanningStateRoute");
			
			_routeButton.title = @"New route";
			_routeButton.style = UIBarButtonItemStyleBordered;
			
			_searchButton.enabled = NO;
			
			items=@[_locationButton,_searchButton,_leftFlex, _changePlanButton,_routeButton];
            [self.toolBar setItems:items animated:NO ];
		}
		break;
	}
	
}



//------------------------------------------------------------------------------------
#pragma mark - Core Location
//------------------------------------------------------------------------------------
//
/***********************************************
 * @description			Location Manager methods
 ***********************************************/
//

-(void)startLocating{
	
	[[UserLocationManager sharedInstance] startUpdatingLocationForSubscriber:LOCATIONSUBSCRIBERID];
	
	[self updateUItoState:MapPlanningStateLocating];
	
}

-(void)stopLocating{
	
	[[UserLocationManager sharedInstance] stopUpdatingLocationForSubscriber:LOCATIONSUBSCRIBERID];
	
	[self updateUItoState:_previousUIState];
	
}


-(void)locationDidComplete:(NSNotification *)notification{
	
	// update ui state
	[self updateUItoState:_previousUIState];
	
	// update map
	
}

-(void)locationDidUpdate:(NSNotification *)notification{
	
	// update map
	
	
}

-(void)locationDidFail:(NSNotification *)notification{
	
	// update ui state
	[self updateUItoState:_previousUIState];
	
}


//------------------------------------------------------------------------------------
#pragma mark - Waypoints
//------------------------------------------------------------------------------------
//
/***********************************************
 * @description			Waypoints
 ***********************************************/
//


-(void)resetWayPoints{
	
	[_waypointArray removeAllObjects];
	
	[[_mapView markerManager] removeMarkers];
}


-(void)assessWayPointAddition:(CLLocationCoordinate2D)cooordinate{
	
	
	BOOL acceptWaypoint=YES;
	
	// location is too near any other locations> reject
	if (_programmaticChange && _uiState==MapPlanningStatePlanning) {
		
		acceptWaypoint=[self assesWaypointLocationDistance:cooordinate];
		
		if(acceptWaypoint==NO){
			[[HudManager sharedInstance] showHudWithType:HUDWindowTypeError withTitle:@"Point error" andMessage:@"Move the map to set a this point further away."];
			[self updateUItoState:_previousUIState];
		}
	}
	
	
	//explicit click while autolocation was happening. Turn off auto, accept click.
	if (!_programmaticChange) {
		if (_uiState==MapPlanningStateLocating) {
			[self stopLocating];
		}
	}
	
	
	// call addWayPointAtCoordinate
	[self addWayPointAtCoordinate:cooordinate];
	
	// update uistate based on number of coords
	if(_waypointArray.count>1){
		[self updateUItoState:MapPlanningStatePlanning];
	}else if(_waypointArray.count==1){
		[self updateUItoState:MapPlanningStateStartPlanning];
	}
	
	[self saveLocation:cooordinate];
}


-(void)addWayPointAtCoordinate:(CLLocationCoordinate2D)coords{
	
	WayPointVO *waypoint=[WayPointVO new];
	
	RMMarker *marker=nil;
	if([_mapView.markerManager markers].count==0){
		marker=[Markers markerStart];
		waypoint.waypointType=WayPointTypeStart;
	}else if([_mapView.markerManager markers].count==1){
		marker=[Markers markerEnd];
		waypoint.waypointType=WayPointTypeFinish;
	}else{
		marker=[Markers markerIntermediate:@"3"];
		waypoint.waypointType=WayPointTypeIntermediate;
	}
	
	[[_mapView markerManager ] addMarker:marker AtLatLong:coords];
	
	waypoint.marker=marker;
	waypoint.coordinate=coords;
	
	[_waypointArray addObject:waypoint];
	
	
}

-(void)moveWayPointAtIndex:(int)startindex toIndex:(int)endindex{
	
	[_waypointArray exchangeObjectAtIndex:startindex withObjectAtIndex:endindex];
	
}



-(void)removeWayPointAtIndex:(int)index{
	
	WayPointVO *waypoint=[_waypointArray objectAtIndex:index];
	
	[[_mapView markerManager ] removeMarker:waypoint.marker];
	
	[_waypointArray removeObject:waypoint];
	
	// update uistate
	
}

#pragma marl RMMap marker

- (BOOL)canBecomeFirstResponder {
	return YES;
}


-(void)tapOnMarker:(RMMarker *)marker onMap:(RMMapView *)map{
	
	if(_markerMenuOpen==YES)
		return;
	
	UIMenuController *menuController = [UIMenuController sharedMenuController];
	
	if(menuController.isMenuVisible==NO){
		
		[self becomeFirstResponder];
		
		MarkerMenuItem *menuItem = [[MarkerMenuItem alloc] initWithTitle:@"Remove" action:@selector(removeMarkerAtIndexViaMenu:)];
		//menuItem.waypoint= // find marker in marker manager markers array,> indexofObject
		menuController.menuItems = [NSArray arrayWithObject:menuItem];
		
	}
	
	CGRect markerRect=CGRectMake(marker.frame.origin.x-12, marker.frame.origin.y+5, marker.frame.size.width, marker.frame.size.height);
	[menuController setTargetRect:markerRect inView:self.mapView];
	
	if(menuController.isMenuVisible==NO)
		[menuController setMenuVisible:YES animated:YES];
	
	_markerMenuOpen=YES;
	
}


-(void)removeMarkerAtIndexViaMenu:(UIMenuController*)menuController {
	
	MarkerMenuItem *menuItem = [[[UIMenuController sharedMenuController] menuItems] objectAtIndex:0];
	
	if(menuItem.waypoint){
		
		// call remove marker workflow
		
		
	}
	
	_markerMenuOpen=NO;
	
}


//------------------------------------------------------------------------------------
#pragma mark - UI Alerts
//------------------------------------------------------------------------------------
//
/***********************************************
 * @description			UIAlerts
 ***********************************************/
//

// create alert with Type

-(void)createAlertForType:(MapAlertType)type{
	
	UIAlertView		*alert= [[UIAlertView alloc]
							 initWithTitle:@"CycleStreets"
							 message:nil
							 delegate:self
							 cancelButtonTitle:@"Cancel"
							 otherButtonTitles:@"OK", nil];
	self.alertType=type;
	
	switch (type) {
		case MapAlertTypeClearRoute:
			
			alert.message=@"Clear current route?";
			
			break;
		 default:
			
			break;
	}
	
	[alert show];
	
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	
	
	switch (_alertType) {
			
		case MapAlertTypeClearRoute:
			
			if (buttonIndex != alertView.cancelButtonIndex) {
				[[RouteManager sharedInstance] selectRoute:nil];
			}
			
		break;
			
		default:
			break;
	}
	

}


//------------------------------------------------------------------------------------
#pragma mark - UIEvents
//------------------------------------------------------------------------------------
//
/***********************************************
 * @description			UIEvents
 ***********************************************/
//


- (void) locationButtonSelected {
	
	BetterLog(@"");
	
	if(_uiState==MapPlanningStateLocating){
		[self stopLocating];
	}else{
		[self startLocating];
	}
	
}



- (IBAction) searchButtonSelected {
	
	BetterLog(@"");
	
	if (self.mapLocationSearchView == nil) {
		self.mapLocationSearchView = [[MapLocationSearchViewController alloc] initWithNibName:@"MapLocationSearchView" bundle:nil];
	}
	_mapLocationSearchView.locationReceiver = self;
	_mapLocationSearchView.centreLocation = [[_mapView contents] mapCenter];
	
	[self presentModalViewController:_mapLocationSearchView	animated:YES];
	
}



- (IBAction) routeButtonSelected {
	
	BetterLog(@"");
	
	if (_uiState == MapPlanningStatePlanning) {
		
		[[RouteManager sharedInstance] loadRouteForWaypoints:_waypointArray];
		
	} else if (_uiState == MapPlanningStateRoute) {
		
		[self createAlertForType:MapAlertTypeClearRoute];
		
	}
}


-(void)waypointButtonSelected{
	
	BetterLog(@"");
	
	WayPointViewController *waypointController=(WayPointViewController*)self.viewDeckController.leftController;
	waypointController.dataProvider=_waypointArray;
	
	[self.viewDeckController openLeftViewAnimated:YES];
	
}



/***********************************************
 * @description			ROUTE PLAN POPUP METHODS
 ***********************************************/
//

-(IBAction)showRoutePlanMenu:(id)sender{
	
    self.routeplanView=[[RoutePlanMenuViewController alloc]initWithNibName:@"RoutePlanMenuView" bundle:nil];
	_routeplanView.plan=_route.plan;
    
	self.routeplanMenu = [[popoverClass alloc] initWithContentViewController:_routeplanView];
	_routeplanMenu.delegate = self;
	
	[_routeplanMenu presentPopoverFromBarButtonItem:_changePlanButton toolBar:_toolBar permittedArrowDirections:UIPopoverArrowDirectionUp animated:YES];
    
	
}


-(void)didSelectNewRoutePlan:(NSNotification*)notification{
	
	NSDictionary *userInfo=notification.userInfo;
	
	[[RouteManager sharedInstance] loadRouteForRouteId:_route.routeid withPlan:[userInfo objectForKey:@"planType"]];
	
	[_routeplanMenu dismissPopoverAnimated:YES];
	
}




#pragma mark RMMap delegate methods
//
/***********************************************
 * @description			RMMap Touch delegates
 ***********************************************/
//

- (void) singleTapOnMap: (RMMapView*) map At: (CGPoint) point {
	
	if(_singleTapDidOccur==NO){
		_singleTapDidOccur=YES;
		_singleTapPoint=point;
		[self performSelector:@selector(singleTapDelayExpired) withObject:nil afterDelay:ACCIDENTAL_TAP_DELAY];
		
	}
}

-(void)doubleTapOnMap:(RMMapView*)map At:(CGPoint)point{
	
	_singleTapDidOccur=NO;
	
	float nextZoomFactor = [map.contents nextNativeZoomFactor];
	if (nextZoomFactor != 0)
		[map zoomByFactor:nextZoomFactor near:point animated:YES];
	
}


- (void) singleTapDelayExpired {
	if(_singleTapDidOccur==YES){
		_singleTapDidOccur=NO;
		CLLocationCoordinate2D location = [_mapView pixelToLatLong:_singleTapPoint];
		[self addWayPointAtCoordinate:location];
	}
}


- (void) afterMapChanged: (RMMapView*) map {
	
	[_lineView setNeedsDisplay];
	[_blueCircleView setNeedsDisplay];
	
	if (!self.programmaticChange) {
		
		if(_uiState==MapPlanningStateLocating)
			[self stopLocating];
		
	} else {
		
	}
}


- (void) afterMapMove: (RMMapView*) map {
	[self afterMapChanged:map];
}

-(void)afterMapTouch:(RMMapView *)map{
	
	map.enableDragging=YES;
	
}


- (void) afterMapZoom: (RMMapView*) map byFactor: (float) zoomFactor near:(CGPoint) center {
    
	[self afterMapChanged:map];
	[self saveLocation:map.contents.mapCenter];
}


#pragma mark map location persistence
//
/***********************************************
 * @description			Saves Map location
 ***********************************************/
//

- (void)saveLocation:(CLLocationCoordinate2D)location {
	NSMutableDictionary *misc = [NSMutableDictionary dictionaryWithDictionary:[[CycleStreets sharedInstance].files misc]];
	[misc setValue:[NSString stringWithFormat:@"%f", location.latitude] forKey:@"latitude"];
	[misc setValue:[NSString stringWithFormat:@"%f", location.longitude] forKey:@"longitude"];
	[misc setValue:[NSString stringWithFormat:@"%f", _mapView.contents.zoom] forKey:@"zoom"];
	[[CycleStreets sharedInstance].files setMisc:misc];
}

//
/***********************************************
 * @description			Loads any saved map lat/long and zoom
 ***********************************************/
//
-(void)loadLocation{
	
	BetterLog(@"");
	
	NSDictionary *misc = [[CycleStreets sharedInstance].files misc];
	NSString *sLat = [misc valueForKey:@"latitude"];
	NSString *sLon = [misc valueForKey:@"longitude"];
	NSString *sZoom = [misc valueForKey:@"zoom"];
	
	CLLocationCoordinate2D initLocation;
	if (sLat != nil && sLon != nil) {
		initLocation.latitude = [sLat doubleValue];
		initLocation.longitude = [sLon doubleValue];
		[_mapView moveToLatLong:initLocation];
		
		if ([_mapView.contents zoom] < MAX_ZOOM) {
			[_mapView.contents setZoom:[sZoom floatValue]];
		}
		[_lineView setNeedsDisplay];
		[_blueCircleView setNeedsDisplay];
		[self stopLocating];
	}
}

- (BOOL)locationInBounds:(CLLocationCoordinate2D)location {
	CGRect bounds = _mapView.contents.screenBounds;
	CLLocationCoordinate2D nw = [_mapView pixelToLatLong:bounds.origin];
	CLLocationCoordinate2D se = [_mapView pixelToLatLong:CGPointMake(bounds.origin.x + bounds.size.width, bounds.origin.y + bounds.size.height)];
	
	if (nw.latitude < location.latitude) return NO;
	if (nw.longitude > location.longitude) return NO;
	if (se.latitude > location.latitude) return NO;
	if (se.longitude < location.longitude) return NO;
	
	return YES;
}

#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
- (BOOL) assesWaypointLocationDistance:(CLLocationCoordinate2D)locationLatLon {
	
	for (WayPointVO *waypoint in _waypointArray) {
		
		CLLocationCoordinate2D fromLatLon = waypoint.coordinate;
		
		CLLocation *from = [[CLLocation alloc] initWithLatitude:fromLatLon.latitude
													  longitude:fromLatLon.longitude];
		CLLocation *to = [[CLLocation alloc] initWithLatitude:locationLatLon.latitude
													longitude:locationLatLon.longitude];
		CLLocationDistance distance = [from getDistanceFrom:to];
		
		if(distance<MIN_START_FINISH_DISTANCE){
			return NO;
		}
		
	}
	return YES;
}


//------------------------------------------------------------------------------------
#pragma mark - Class methods
//------------------------------------------------------------------------------------
//
/***********************************************
 * @description			CLASS METHODS
 ***********************************************/
//


+ (NSArray *)mapStyles {
	return [NSArray arrayWithObjects:MAPPING_BASE_OSM, MAPPING_BASE_OPENCYCLEMAP, MAPPING_BASE_OS,nil];
}

+ (NSString *)currentMapStyle {
	NSString *mapStyle = [SettingsManager sharedInstance].dataProvider.mapStyle;
	if (mapStyle == nil) {
		mapStyle = [[NewMapViewController mapStyles] objectAtIndex:0];
	}
	
	return mapStyle;
}

+ (NSString *)mapAttribution {
	NSString *mapStyle = [NewMapViewController currentMapStyle];
	NSString *mapAttribution = nil;
	if ([mapStyle isEqualToString:MAPPING_BASE_OSM]) {
		mapAttribution = MAPPING_ATTRIBUTION_OSM;
	} else if ([mapStyle isEqualToString:MAPPING_BASE_OPENCYCLEMAP]) {
		mapAttribution = MAPPING_ATTRIBUTION_OPENCYCLEMAP;
	}else if ([mapStyle isEqualToString:MAPPING_BASE_OS]) {
		mapAttribution = MAPPING_ATTRIBUTION_OS;
	}
	return mapAttribution;
}

+ ( NSObject <RMTileSource> *)tileSource {
	NSString *mapStyle = [NewMapViewController currentMapStyle];
	NSObject <RMTileSource> *tileSource;
	if ([mapStyle isEqualToString:MAPPING_BASE_OSM])
	{
		tileSource = [[RMOpenStreetMapSource alloc] init];
	}
	else if ([mapStyle isEqualToString:MAPPING_BASE_OPENCYCLEMAP])
	{
		//open cycle map
		tileSource = [[RMOpenCycleMapSource alloc] init];
	}
	else if ([mapStyle isEqualToString:MAPPING_BASE_OS])
	{
		//Ordnance Survey
		tileSource = [[RMOrdnanceSurveyStreetViewMapSource alloc] init];
	}
	else
	{
		//default to MAPPING_BASE_OSM.
		tileSource = [[RMOpenStreetMapSource alloc] init];
	}
	return tileSource;
}

+ (void)zoomMapView:(RMMapView *)mapView toLocation:(CLLocation *)newLocation {
	CLLocationAccuracy accuracy = newLocation.horizontalAccuracy;
	if (accuracy < 0) {
		accuracy = 2000;
	}
	int wantZoom = MAX_ZOOM_LOCATION;
	CLLocationAccuracy wantAccuracy = MAX_ZOOM_LOCATION_ACCURACY;
	while (wantAccuracy < accuracy) {
		wantZoom--;
		wantAccuracy = wantAccuracy * 2;
	}
	
	[mapView moveToLatLong: newLocation.coordinate];
	[mapView.contents setZoom:wantZoom];
}



//
/***********************************************
 * @description			DELEGATE METHODS
 ***********************************************/
//


#pragma mark Mapsearch delegate

- (void) didMoveToLocation:(CLLocationCoordinate2D)location {
	BetterLog(@"didMoveToLocation");
	
	[self.mapView moveToLatLong: location];
	
	[self addWayPointAtCoordinate:location];
	[_lineView setNeedsDisplay];
	[_blueCircleView setNeedsDisplay];
	[self stopLocating];
	 
}



#pragma mark WEPopoverControllerDelegate 

- (void)popoverControllerDidDismissPopover:(WEPopoverController *)thePopoverController {
	//Safe to release the popover here
	self.routeplanMenu = nil;
}

- (BOOL)popoverControllerShouldDismissPopover:(WEPopoverController *)thePopoverController {
	//The popover is automatically dismissed if you click outside it, unless you return NO here
	return YES;
}


#pragma mark point list provider 
// PointListProvider
+ (NSArray *) pointList:(RouteVO *)route withView:(RMMapView *)mapView {
	
	NSMutableArray *points = [[NSMutableArray alloc] initWithCapacity:10];
	if (route == nil) {
		return points;
	}
	
	for (int i = 0; i < [route numSegments]; i++) {
		if (i == 0)
		{	// start of first segment
			CSPointVO *p = [[CSPointVO alloc] init];
			SegmentVO *segment = [route segmentAtIndex:i];
			CLLocationCoordinate2D coordinate = [segment segmentStart];
			CGPoint pt = [mapView.contents latLongToPixel:coordinate];
			p.p = pt;
			[points addObject:p];
		}
		// remainder of all segments
		SegmentVO *segment = [route segmentAtIndex:i];
		NSArray *allPoints = [segment allPoints];
		for (int i = 1; i < [allPoints count]; i++) {
			CSPointVO *latlon = [allPoints objectAtIndex:i];
			CLLocationCoordinate2D coordinate;
			coordinate.latitude = latlon.p.y;
			coordinate.longitude = latlon.p.x;
			CGPoint pt = [mapView.contents latLongToPixel:coordinate];
			CSPointVO *screen = [[CSPointVO alloc] init];
			screen.p = pt;
			[points addObject:screen];
		}
	}
	
	return points;
}

- (NSArray *) pointList {
	return [NewMapViewController pointList:self.route withView:self.mapView];
}

// LocationProvider
#pragma mark location provider

- (float)getX {
	CGPoint p = [self.mapView.contents latLongToPixel:self.lastLocation.coordinate];
	return p.x;
}

- (float)getY {
	CGPoint p = [self.mapView.contents latLongToPixel:self.lastLocation.coordinate];
	return p.y;
}

- (float)getRadius {
	
	double metresPerPixel = [self.mapView.contents metersPerPixel];
	float locationRadius=(self.lastLocation.horizontalAccuracy / metresPerPixel);
	
	return MAX(locationRadius, 40.0f);
}


@end
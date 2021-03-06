    //
//  RoutesViewContoller.m
//  CycleStreets
//
//  Created by Neil Edwards on 09/03/2011.
//  Copyright 2011 CycleStreets Ltd. All rights reserved.
//

#import "RoutesViewController.h"
#import "AppConstants.h"
#import "ViewUtilities.h"
#import "StyleManager.h"
#import "RouteListViewController.h"
#import "RouteManager.h"
#import "ButtonUtilities.h"
#import "UIView+Additions.h"
#import "GenericConstants.h"
#import <PixateFreestyle/PixateFreestyle.h>

@interface RoutesViewController()


@property (nonatomic, strong)	IBOutlet BorderView				*controlView;
@property (nonatomic, strong)	BUSegmentedControl				*routeTypeControl;
@property (nonatomic, strong)	IBOutlet UIButton				*selectedRouteButton;

@property (weak, nonatomic) IBOutlet UIView                     *containerView;


@property (nonatomic, strong)	NSMutableArray					*dataTypeArray;

@property (nonatomic, strong)	NSMutableDictionary				*viewStack;
@property (nonatomic, strong)	NSArray							*childControllerData;
@property (nonatomic,strong)  NSString							*activeState;
@property (nonatomic,strong)  SuperViewController				* activeController;

@property (nonatomic, assign)	int								activeIndex;
@property (nonatomic, strong)	CSRouteDetailsViewController					*routeSummary;

-(IBAction)selectedRouteButtonSelected:(id)sender;
-(void)selectedRouteUpdated;

@end


@implementation RoutesViewController


//
/***********************************************
 * @description		NOTIFICATIONS
 ***********************************************/
//

-(void)listNotificationInterests{
	
	[self initialise];
	
	displaysConnectionErrors=NO;
    
    [notifications addObject:CSROUTESELECTED];
	
	[super listNotificationInterests];
	
}

-(void)didReceiveNotification:(NSNotification*)notification{
	
	[super didReceiveNotification:notification];
	
    if([notification.name isEqualToString:CSROUTESELECTED]){
        [self selectedRouteUpdated];
    }
	
}


//
/***********************************************
 * @description			DATA UPDATING
 ***********************************************/
//

-(void)refreshUIFromDataProvider{
	
		
}

-(void)selectedRouteUpdated{
    
    BOOL selectedRouteExists=[RouteManager sharedInstance].selectedRoute!=nil;
    
    _selectedRouteButton.enabled=selectedRouteExists;
    
    if(self.navigationController.topViewController==_routeSummary){
        if(selectedRouteExists==NO){
            [self.navigationController popToRootViewControllerAnimated:NO];
        }
    }
	
    
}


//
/***********************************************
 * @description			UI CREATION
 ***********************************************/
//

- (void)viewDidLoad {
	
	_activeIndex=-1;
	
    [super viewDidLoad];
	
	[self createPersistentUI];
	
	// sets the initial sub view
	int startIndex=1;
	if([SavedRoutesManager sharedInstance].favouritesdataProvider.count>0 )
		startIndex=0;
	
	[_routeTypeControl setSelectedSegmentIndex:startIndex];
	
}


-(void)createPersistentUI{
	
	
	_controlView.backgroundColor=[UIColor whiteColor];
	[_controlView drawBorderwithColor:UIColorFromRGB(0xCCCCCC) andStroke:1 left:NO right:NO top:NO bottom:YES];
	
	LayoutBox *controlcontainer=[[LayoutBox alloc]initWithFrame:CGRectMake(0, 0, SCREENWIDTH, CONTROLUIHEIGHT)];
	controlcontainer.fixedWidth=YES;
	controlcontainer.fixedHeight=YES;
	controlcontainer.itemPadding=15;
	controlcontainer.paddingLeft=15;
	controlcontainer.alignMode=BUCenterAlignMode;
	
	NSMutableArray *sdp = [[NSMutableArray alloc] initWithObjects:@"Favourites", @"Recent",  nil];
	_routeTypeControl=[[BUSegmentedControl alloc]init];
	_routeTypeControl.dataProvider=sdp;
	_routeTypeControl.delegate=self;
	_routeTypeControl.itemWidth=80;
	[_routeTypeControl buildInterface];
	[controlcontainer addSubview:_routeTypeControl];
	
	self.selectedRouteButton=[ButtonUtilities UIPixateButtonWithWidth:120 height:32 styleId:@"OrangeButton" text:@"Current Route"];
    [_selectedRouteButton addTarget:self action:@selector(selectedRouteButtonSelected:) forControlEvents:UIControlEventTouchUpInside];
	
	[controlcontainer addSubview:_selectedRouteButton];
	[_controlView addSubview:controlcontainer];
	
	
	self.viewStack=[NSMutableDictionary dictionary];
    
    self.childControllerData=@[@{ID: SAVEDROUTE_FAVS,CONTROLLER:[RouteListViewController className],@"isSectioned":@(NO)},
                               @{ID: SAVEDROUTE_RECENTS,CONTROLLER:[RouteListViewController className],@"isSectioned":@(YES)}];
	
	
	[self loadChildControllers];
}


-(void)viewWillAppear:(BOOL)animated{
	
	[super viewWillAppear:animated];
	
	[self createNonPersistentUI];
	
}

-(void)createNonPersistentUI{
	
    _selectedRouteButton.enabled=[[RouteManager sharedInstance] selectedRoute]!=nil;
	
}




#pragma mark - UIEvents

-(IBAction)selectedRouteButtonSelected:(id)sender{
    
    if([[RouteManager sharedInstance] selectedRoute]!=nil)
		[self doNavigationPush:@"RouteSummary" withDataProvider:[[RouteManager sharedInstance] selectedRoute] andIndex:-1];
    
}



-(IBAction)didSelectFetchRouteButton:(NSString*)type{
	
	
//	__weak __typeof(&*self)weakSelf = self;
//	
//	UIAlertController *createAlert=[UIAlertController alertControllerWithTitle:@"Enter route number" message:@"Find a CycleStreets route by number" preferredStyle:UIAlertControllerStyleAlert];
//	
//	UIAlertAction *executeAction=[UIAlertAction actionWithTitle:OK style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
//		
//		[[RouteManager sharedInstance] loadRouteForRouteId:createAlert.textFields.firstObject.text];
//		
//		[_routeTypeControl setSelectedSegmentIndex:1];
//		[weakSelf selectedIndexDidChange:1];
//		
//	}];
//	
//	UIAlertAction *cancelAction=[UIAlertAction actionWithTitle:CANCEL style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
//		
//	}];
//	
//	[createAlert addAction:executeAction];
//	[createAlert addAction:cancelAction];
//	[createAlert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
//		textField.placeholder = @"Enter route number";
//		textField.keyboardType = UIKeyboardTypeNumberPad;
//		textField.width=200;
//		
//	}];
//	
//	[self presentViewController:createAlert animated:YES completion:^{
//		
//	}];
//	[createAlert.view layoutIfNeeded];
	
	
	
	
	[ViewUtilities createTextEntryAlertView:@"Enter route number" fieldText:nil withMessage:@"Find a CycleStreets route by number" keyboardType:UIKeyboardTypeNumberPad delegate:self];
	
    
}

#pragma mark - UIAlert delegate

// Note: use of didDismissWithButtonIndex, as otherwise the HUD gets removed by the screen clear up performed by Alert 
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex{
	
	if(buttonIndex > 0) {
        
		switch(alertView.tag){
                
			case kTextEntryAlertTag:
			{
				UITextField *alertInputField=nil;
				// os7 cant get view tag for field
				if(SYSTEM_VERSION_LESS_THAN(@"7.0")){
					alertInputField=(UITextField*)[alertView viewWithTag:kTextEntryAlertFieldTag];
				}else{
					alertInputField=(UITextField*)[alertView textFieldAtIndex:0];
				}
				
				if (alertInputField!=nil && ![alertInputField.text isEqualToString:EMPTYSTRING]){
					[[RouteManager sharedInstance] loadRouteForRouteId:alertInputField.text];
					
					[_routeTypeControl setSelectedSegmentIndex:1];
					[self selectedIndexDidChange:1];
				}
			}
            break;
                
			default:
				
            break;
                
		}
		
	}
	
}



- (void)didPresentAlertView:(UIAlertView *)alertView{
	
	
	switch(alertView.tag){
			
		case kTextEntryAlertTag:
		{
			UITextField *alertInputField=nil;
			// os7 cant get view tag for field
			if(SYSTEM_VERSION_LESS_THAN(@"7.0")){
				alertInputField=(UITextField*)[alertView viewWithTag:kTextEntryAlertFieldTag];
			}else{
				alertInputField=(UITextField*)[alertView textFieldAtIndex:0];
			}
			[UIView animateWithDuration:0.3 animations:^{
				alertInputField.width=200;
				alertInputField.x-=100;
				alertInputField.height=36;
				alertInputField.y-=5;
			}];
			
			alertInputField.borderStyle=UITextBorderStyleLine;
		}
			break;
			
		default:
			
		break;
			
	}
	
}



#pragma mark - Segment control

-(void)selectedIndexDidChange:(NSInteger)index{
	
    if(index!=-1){
		
		[self swapChildViewControllerToType:_childControllerData[index]];
	
	}
	
}




#pragma mark - Child controllers


-(void)loadChildControllers{
	
	
	for(NSDictionary *configDict in _childControllerData){
		
		RouteListViewController *controller=[[RouteListViewController alloc]initWithNibName:[RouteListViewController nibName] bundle:nil];
		
		[controller willMoveToParentViewController:self];
		[_containerView addSubview:controller.view];
		[self addChildViewController:controller];
		[controller didMoveToParentViewController:self];
		controller.delegate=self;
		[controller setValue:configDict forKey:@"configDict"];
		[_viewStack setObject:controller forKey:configDict[ID]];
		
		controller.view.size=_containerView.size;
	}
	
	[_containerView layoutSubviews];
	
	
    NSDictionary *controllerDict=_childControllerData[1];
    NSString *controllerName=controllerDict[ID];
    self.activeState=controllerName;
    self.activeController=[self.childViewControllers objectAtIndex:1];
	
	[_activeController refreshUIFromDataProvider];
}


-(void)swapChildViewControllerToType:(NSDictionary*)dict{
    
    SuperViewController *_oldcontroller=_activeController;
    
    NSString *controller=dict[ID];
	
	if([controller isEqualToString:_activeState])
		return;
	
	
    self.activeState=controller;
	
    SuperViewController *_newcontroller=[_viewStack objectForKey:controller];
    [_oldcontroller willMoveToParentViewController:nil];
    
    [self transitionFromViewController:_oldcontroller toViewController:_newcontroller duration:0.2 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{} completion:^(BOOL finished) {
        [_newcontroller didMoveToParentViewController:self];
        self.activeController=_newcontroller;
		[_activeController refreshUIFromDataProvider];
    }];
    
    
}


-(NSDictionary*)childControllerDictForType:(NSString*)type{
	
	for(NSDictionary *dict in _childControllerData){
		
		if([dict[ID] isEqualToString:type]){
			return dict;
		}
		
	}
	return nil;
}


//
/***********************************************
 * @description			ViewController delegate method
 ***********************************************/
//
-(void)doNavigationPush:(NSString*)className withDataProvider:(id)data andIndex:(int)index{
    
    if([className isEqualToString:@"RouteSummary"]){
        
        if (self.routeSummary == nil) {
            self.routeSummary = [[CSRouteDetailsViewController alloc]init];
        }
        self.routeSummary.route = (RouteVO*)data;
		_routeSummary.dataType=index;
        [self showUniqueViewController:_routeSummary];
        
    }
    
}



//
/***********************************************
 * @description			GENERIC METHODS
 ***********************************************/
//

- (void)didReceiveMemoryWarning {
   [super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
    [super viewDidUnload];
}




@end

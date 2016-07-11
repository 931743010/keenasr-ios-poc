//
//  EduWordsDemoViewController.m
//  kaldi-ios-poc
//
//  Created by Ognjen Todic on 6/27/16.
//  Copyright © 2016 Keen Research. All rights reserved.
//

#import "EduWordsDemoViewController.h"

@interface EduWordsDemoViewController()
@property (nonatomic, strong) UIButton *startListeningButton, *backButton;
@property (nonatomic, strong) UILabel *textLabel, *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, assign) BOOL initializedDecodingGraph;
@property (nonatomic, strong) NSArray *words;

// just to make it easier to access recognizer throught this class
@property (nonatomic, weak) KIOSRecognizer *recognizer;

@end


@implementation EduWordsDemoViewController


- (void)viewDidLoad {
  [super viewDidLoad];
  
  // Do any additional setup after loading the view.
  NSLog(@"Starting edu-words demo");
  
  self.words = [self getWords];
  self.view.backgroundColor = [UIColor whiteColor];
  
  // back button
  self.backButton = [UIButton buttonWithType:UIButtonTypeSystem];
  self.backButton.frame = CGRectMake(5, 5, 100, 20);
  self.backButton.titleLabel.font = [UIFont systemFontOfSize:18];
  self.backButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
  self.backButton.backgroundColor = [UIColor clearColor];
  [self.backButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
  [self.backButton setTitleColor:[UIColor grayColor] forState:UIControlStateDisabled];
  [self.backButton setTitle:@"Back" forState:UIControlStateNormal];
  [self.backButton addTarget:self action:@selector(backButtonTapped:) forControlEvents:UIControlEventTouchDown];
  [self.view addSubview:self.backButton];
  self.backButton.enabled = NO;
  
  // start button
  self.startListeningButton = [UIButton buttonWithType:UIButtonTypeSystem];
  float width=220, height=40;
  self.startListeningButton.frame = CGRectMake((CGRectGetWidth(self.view.frame)-width)/2,
                                               CGRectGetHeight(self.view.frame)-height - 5,
                                               width,
                                               height);
  self.startListeningButton.titleLabel.font = [UIFont systemFontOfSize:30];
  [self.view addSubview:self.startListeningButton];
  self.startListeningButton.backgroundColor = [UIColor clearColor];
  [self.startListeningButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
  [self.startListeningButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
  [self.startListeningButton setTitle:@"TAP TO START" forState:UIControlStateNormal];
  [self.startListeningButton addTarget:self action:@selector(startListeningButtonTapped:) forControlEvents:UIControlEventTouchDown];
  self.startListeningButton.alpha = 0;
  
  // setup results label
  float w = CGRectGetWidth(self.view.frame) - 120;
  float h = 200;
  CGRect frame = CGRectMake((CGRectGetWidth(self.view.frame)-w)/2,
                            (CGRectGetHeight(self.view.frame)-h)/2,
                            w, h);
  self.textLabel = [[UILabel alloc] initWithFrame:frame];
  self.textLabel.textAlignment = NSTextAlignmentLeft;
  self.textLabel.font = [UIFont systemFontOfSize:45];
  self.textLabel.numberOfLines = 0;
  [self.textLabel setAdjustsFontSizeToFitWidth:YES];
  self.textLabel.textColor = [UIColor blackColor];
  self.textLabel.backgroundColor = [UIColor clearColor];
  [self.view addSubview:self.textLabel];
  
  
  // spinner
  self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
  float spWidth = 100, spHeight = 100;
  self.spinner.frame = CGRectMake(CGRectGetWidth(self.view.frame)/2 - spWidth/2,
                                  CGRectGetHeight(self.view.frame)/2 - spHeight/2,
                                  spWidth,
                                  spHeight);
  [self.view addSubview:self.spinner];
  self.spinner.alpha = 0;
  
  // status label
  float slWidth = 300, slHeight=20;
  self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(CGRectGetWidth(self.view.frame)/2-slWidth/2, 5, slWidth, slHeight)];
  self.statusLabel.textAlignment = NSTextAlignmentCenter;
  self.statusLabel.font = [UIFont systemFontOfSize:18];
  self.statusLabel.numberOfLines = 0;
  [self.statusLabel setAdjustsFontSizeToFitWidth:YES];
  self.statusLabel.textColor = [UIColor grayColor];
  self.statusLabel.backgroundColor = [UIColor clearColor];
  
  [self.view addSubview:self.statusLabel];
  
  
  // keeping weak local reference just so we don't have to call shared instance
  // all the time
  self.recognizer = [KIOSRecognizer sharedInstance];
  [KIOSRecognizer setLogLevel:KIOSRecognizerLogLevelInfo];
  
  // setup self to be the delegate for the recognizer so we get notifications
  // for partial/final results
  self.recognizer.delegate = self;
  
  // set Voice Activity Detection timeouts
  // if user doesn't say anything for this many seconds we end recognition
  [self.recognizer setVADParameter:KIOSVadTimeoutForNoSpeech toValue:10];
  // we never run recognition longer than this many seconds
  [self.recognizer setVADParameter:KIOSVadTimeoutMaxDuration toValue:20];
  // end silence timeouts (somewhat arbitrary); too long and it may be weird
  // if the user finished. Too short and we may cut them off if they pause for a
  // while.
  [self.recognizer setVADParameter:KIOSVadTimeoutEndSilenceForGoodMatch toValue:1];
  // use the same setting here as for the good match, although this could be
  // slightly longer
  [self.recognizer setVADParameter:KIOSVadTimeoutEndSilenceForAnyMatch toValue:2];
  
  self.startListeningButton.enabled = NO;
  
  // on first tap we will initialize the
  // decoder with the custom decoding graph via startListningWithCustomDecodingGraph
  // and set this to YES, so that subsequent taps on Start trigger only startListening
  self.initializedDecodingGraph = NO;
}



- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  
  self.spinner.alpha = 1;
  [self.spinner startAnimating]; //
  
  self.statusLabel.text = @"Creating decoding graph...";
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  
  NSLog(@"View appeared, setting up decoding graph now");
  
  KIOSDecodingGraph *dg = [[KIOSDecodingGraph alloc] initWithRecognizer:self.recognizer];
  
  
  // we'll create decoding graph based on the sentences in the paragraph presented
  // to the user
  NSArray *sentences = [self createSentences];
  if ([sentences count] == 0) {
    self.statusLabel.text = @"Unable to create a list of sentences for the decoding graph";
    return;
  }
  
  // explore these two methods just for fun; regardless we will recreate the
  // decoding graph
  NSString *dgName = @"words";
  if ([dg decodingGraphExists:dgName]) {
    NSLog(@"Custom decoding graph '%@' exists", dgName);
    NSDate *createdOn = [dg decodingGraphCreationDate:dgName];
    NSLog(@"It was created on %@", createdOn);
  } else {
    NSLog(@"Decoding graph '%@' doesn't exist", dgName);
  }
  
  // create custom decoding graph with (arbitraty) name 'reading' using
  // sentences obtained above
  if (! [dg createDecodingGraphFromSentences:sentences andSaveWithName:@"words"]) {
    self.textLabel.text = @"Error occured while creating decoding graph from the text";
    [self.spinner stopAnimating];
    self.spinner.alpha = 0;
    return;
  }
  
  [self.spinner stopAnimating];
  self.spinner.alpha = 0;
  self.statusLabel.text = @"Completed decoding graph"; // TODO - add num songs/artists
  
  [self.spinner stopAnimating];
  self.spinner.alpha = 0;
  // Note that this decoding graph doesn't need to be created in this view controller.
  // It could have been created any time; we just need to know the name so we can
  // reference it when starting to listen
  
  self.textLabel.textColor = [UIColor lightGrayColor];
  self.textLabel.textAlignment = UIControlContentHorizontalAlignmentLeft;
  self.textLabel.text = @"Tap the button and then say \"How do you spell <WORD>\" or \"Spell <WORD> \". Only 1000 most frequently used words are recognized (real app can allow parents to add additional words of interest)";
  
  self.startListeningButton.alpha = 1;
  self.startListeningButton.enabled = YES;
  self.backButton.enabled = YES;
}



- (void)startListeningButtonTapped:(id)sender {
  self.startListeningButton.enabled = NO;
  self.textLabel.text = @"";
  self.textLabel.textColor = [UIColor lightGrayColor];
  self.statusLabel.text = @"Listening...";
  
  
  // start listening using decoding graph we created in viewDidAppear
  if (! self.initializedDecodingGraph) {
    [self.recognizer startListeningWithCustomDecodingGraph:@"words"];
    self.initializedDecodingGraph = YES;
  } else {
    [self.recognizer startListening]; // decoding graph is already set so we can just call startListening
    // this if/else is not mandatory, but there is some overhead in loading the
    // decoding graph so if we continue listening with the same graph it's better
    // to call startListening
  }
}


- (void)backButtonTapped:(id)sender {
  if ([self.recognizer listening])
    [self.recognizer stopListening];
  
  [self dismissViewControllerAnimated:YES completion:^{}];
}


- (NSString *)spotKeyword:(NSString *)phrase {
  // strip prefix, if exists (not the most efficient way to do this)
  phrase = [phrase stringByReplacingOccurrencesOfString:@"HOW DO YOU SPELL" withString:@""];
  phrase = [phrase stringByReplacingOccurrencesOfString:@"HOW DO YOU" withString:@""];
  phrase = [phrase stringByReplacingOccurrencesOfString:@"HOW DO" withString:@""];
  phrase = [phrase stringByReplacingOccurrencesOfString:@"HOW" withString:@""];
  phrase = [phrase stringByReplacingOccurrencesOfString:@"SPELL" withString:@""];
  
  if ([phrase length]==0)
    return nil;
  
  phrase = [phrase stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  NSLog(@"Phrase is '%@'", phrase);
  
  for (NSString *word in self.words) {
//    NSLog(@"Comparing to %@", word);
    if ([word isEqualToString:phrase])
      return word;
  }
  
  return nil;
}


#pragma mark KIOSRecognizer delegate methods

// This demo relies on the partial results for higlighting,
- (void)recognizerPartialResult:(KIOSResult *)result forRecognizer:(KIOSRecognizer *)recognizer {
  NSLog(@"Partial Result: %@ (%@)", result.cleanText, result.text);
  
  NSString *keyword = [self spotKeyword:result.cleanText];
  NSLog(@"Got '%@'", keyword);
  if (keyword == nil)  // no match
    return;
  
  self.textLabel.text = keyword;
//  [self.recognizer stopListening];
}


// NOTE: we update ROS label here as well, but it will be sligtly off because
// we are including endTimeout silence as well. In the future, KIOSResult class
// will provide start/end times for individual words; then, we could look up the
// end time of the last word to do a final ROS estimation
- (void)recognizerFinalResult:(KIOSResult *)result forRecognizer:(KIOSRecognizer *)recognizer {
  NSLog(@"Final Result: %@ (%@, conf: %@)", result.cleanText, result.text, result.confidence);
  
  NSString *keyword = [self spotKeyword:result.cleanText];
  if (keyword != nil)
    self.textLabel.text = keyword;

  self.textLabel.textColor = [UIColor blackColor];
  // maybe we should restart listening if the keyword wasn't spotted
  // in a real app that would be tied to the UX, which we are not dealing with here
  
  if (recognizer.createAudioRecordings)
    NSLog(@"Audio recording is in %@", recognizer.lastRecordingFilename);
  
  self.statusLabel.text = @"Done Listening";
  self.startListeningButton.enabled = YES;
}


- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
  return UIInterfaceOrientationMaskLandscape;
}




- (NSArray *)createSentences {
  NSMutableArray *sentences = [NSMutableArray new];

  for (NSString *word in self.words) {
    NSString *s = [NSString stringWithFormat:@"How do you spell %@", word];
    [sentences addObject:s];

    NSString *s1 = [NSString stringWithFormat:@"spell %@", word];
    [sentences addObject:s1];
    
    [sentences addObject:word];
  }
  
  return sentences;
}

// http://www.readingrockets.org/article/basic-spelling-vocabulary-list
// augmented with days of week, and months
- (NSArray *)getWords {
  return @[@"ALL",
           @"AND",
           @"AT",
           @"BALL",
           @"BE",
           @"BED",
           @"BIG",
           @"BOOK",
           @"BOX",
           @"BOY",
           @"BUT",
           @"CAME",
           @"CAN",
           @"CAR",
           @"CAT",
           @"COME",
           @"COW",
           @"DAD",
           @"DAY",
           @"DID",
           @"DO",
           @"DOG",
           @"FAT",
           @"FOR",
           @"FUN",
           @"GET",
           @"GO",
           @"GOOD",
           @"GOT",
           @"HAD",
           @"HAT",
           @"HE",
           @"HEN",
           @"HERE",
           @"HIM",
           @"HIS",
           @"HOME",
           @"HOT",
           @"I",
           @"IF",
           @"IN",
           @"INTO",
           @"IS",
           @"IT",
           @"ITS",
           @"LET",
           @"LIKE",
           @"LOOK",
           @"MAN",
           @"MAY",
           @"ME",
           @"MOM",
           @"MY",
           @"NO",
           @"NOT",
           @"OF",
           @"OH",
           @"OLD",
           @"ON",
           @"ONE",
           @"OUT",
           @"PAN",
           @"PET",
           @"PIG",
           @"PLAY",
           @"RAN",
           @"RAT",
           @"RED",
           @"RIDE",
           @"RUN",
           @"SAT",
           @"SEE",
           @"SHE",
           @"SIT",
           @"SIX",
           @"SO",
           @"STOP",
           @"SUN",
           @"TEN",
           @"THIS",
           @"TO",
           @"TOP",
           @"TOY",
           @"TWO",
           @"UP",
           @"US",
           @"WAS",
           @"WE",
           @"WILL",
           @"YES",
           @"YOU",
           @"ABOUT",
           @"ADD",
           @"AFTER",
           @"AGO",
           @"AN",
           @"ANY",
           @"APPLE",
           @"ARE",
           @"AS",
           @"ASK",
           @"ATE",
           @"AWAY",
           @"BABY",
           @"BACK",
           @"BAD",
           @"BAG",
           @"BASE",
           @"BAT",
           @"BEE",
           @"BEEN",
           @"BEFORE",
           @"BEING",
           @"BEST",
           @"BIKE",
           @"BILL",
           @"BIRD",
           @"BLACK",
           @"BLUE",
           @"BOAT",
           @"BOTH",
           @"BRING",
           @"BROTHER",
           @"BROWN",
           @"BUS",
           @"BUY",
           @"BY",
           @"CAKE",
           @"CALL",
           @"CANDY",
           @"CHANGE",
           @"CHILD",
           @"CITY",
           @"CLEAN",
           @"CLUB",
           @"COAT",
           @"COLD",
           @"COMING",
           @"CORN",
           @"COULD",
           @"CRY",
           @"CUP",
           @"CUT",
           @"DADDY",
           @"DEAR",
           @"DEEP",
           @"DEER",
           @"DOING",
           @"DOLL",
           @"DOOR",
           @"DOWN",
           @"DRESS",
           @"DRIVE",
           @"DROP",
           @"DRY",
           @"DUCK",
           @"EACH",
           @"EAT",
           @"EATING",
           @"EGG",
           @"END",
           @"FALL",
           @"FAR",
           @"FARM",
           @"FAST",
           @"FATHER",
           @"FEED",
           @"FEEL",
           @"FEET",
           @"FELL",
           @"FIND",
           @"FINE",
           @"FIRE",
           @"FIRST",
           @"FISH",
           @"FIVE",
           @"FIX",
           @"FLAG",
           @"FLOOR",
           @"FLY",
           @"FOOD",
           @"FOOT",
           @"FOUR",
           @"FOX",
           @"FROM",
           @"FULL",
           @"FUNNY",
           @"GAME",
           @"GAS",
           @"GAVE",
           @"GIRL",
           @"GIVE",
           @"GLAD",
           @"GOAT",
           @"GOES",
           @"GOING",
           @"GOLD",
           @"GONE",
           @"GRADE",
           @"GRASS",
           @"GREEN",
           @"GROW",
           @"HAND",
           @"HAPPY",
           @"HARD",
           @"HAS",
           @"HAVE",
           @"HEAR",
           @"HELP",
           @"HERE",
           @"HILL",
           @"HIT",
           @"HOLD",
           @"HOLE",
           @"HOP",
           @"HOPE",
           @"HORSE",
           @"HOUSE",
           @"HOW",
           @"ICE",
           @"INCH",
           @"INSIDE",
           @"JOB",
           @"JUMP",
           @"JUST",
           @"KEEP",
           @"KING",
           @"KNOW",
           @"LAKE",
           @"LAND",
           @"LAST",
           @"LATE",
           @"LAY",
           @"LEFT",
           @"LEG",
           @"LIGHT",
           @"LINE",
           @"LITTLE",
           @"LIVE",
           @"LIVES",
           @"LONG",
           @"LOOKING",
           @"LOST",
           @"LOT",
           @"LOVE",
           @"MAD",
           @"MADE",
           @"MAKE",
           @"MANY",
           @"MEAT",
           @"MEN",
           @"MET",
           @"MILE",
           @"MILK",
           @"MINE",
           @"MISS",
           @"MOON",
           @"MORE",
           @"MOST",
           @"MOTHER",
           @"MOVE",
           @"MUCH",
           @"MUST",
           @"MYSELF",
           @"NAIL",
           @"NAME",
           @"NEED",
           @"NEW",
           @"NEXT",
           @"NICE",
           @"NIGHT",
           @"NINE",
           @"NORTH",
           @"NOW",
           @"NUT",
           @"OFF",
           @"ONLY",
           @"OPEN",
           @"OR",
           @"OTHER",
           @"OUR",
           @"OUTSIDE",
           @"OVER",
           @"PAGE",
           @"PARK",
           @"PART",
           @"PAY",
           @"PICK",
           @"PLANT",
           @"PLAYING",
           @"PONY",
           @"POST",
           @"PULL",
           @"PUT",
           @"RABBIT",
           @"RAIN",
           @"READ",
           @"REST",
           @"RIDING",
           @"ROAD",
           @"ROCK",
           @"ROOM",
           @"SAID",
           @"SAME",
           @"SANG",
           @"SAW",
           @"SAY",
           @"SCHOOL",
           @"SEA",
           @"SEAT",
           @"SEEM",
           @"SEEN",
           @"SEND",
           @"SET",
           @"SEVEN",
           @"SHEEP",
           @"SHIP",
           @"SHOE",
           @"SHOW",
           @"SICK",
           @"SIDE",
           @"SING",
           @"SKY",
           @"SLEEP",
           @"SMALL",
           @"SNOW",
           @"SOME",
           @"SOON",
           @"SPELL",
           @"START",
           @"STAY",
           @"STILL",
           @"STORE",
           @"STORY",
           @"TAKE",
           @"TALK",
           @"TALL",
           @"TEACH",
           @"TELL",
           @"THAN",
           @"THANK",
           @"THAT",
           @"THEM",
           @"THEN",
           @"THERE",
           @"THEY",
           @"THING",
           @"THINK",
           @"THREE",
           @"TIME",
           @"TODAY",
           @"TOLD",
           @"TOO",
           @"TOOK",
           @"TRAIN",
           @"TREE",
           @"TRUCK",
           @"TRY",
           @"USE",
           @"VERY",
           @"WALK",
           @"WANT",
           @"WARM",
           @"WASH",
           @"WAY",
           @"WEEK",
           @"WELL",
           @"WENT",
           @"WERE",
           @"WET",
           @"WHAT",
           @"WHEN",
           @"WHILE",
           @"WHITE",
           @"WHO",
           @"WHY",
           @"WIND",
           @"WISH",
           @"WITH",
           @"WOKE",
           @"WOOD",
           @"WORK",
           @"YELLOW",
           @"YET",
           @"YOUR",
           @"ZOO",
           @"ABLE",
           @"ABOVE",
           @"AFRAID",
           @"AFTERNOON",
           @"AGAIN",
           @"AGE",
           @"AIR",
           @"AIRPLANE",
           @"ALMOST",
           @"ALONE",
           @"ALONG",
           @"ALREADY",
           @"ALSO",
           @"ALWAYS",
           @"ANIMAL",
           @"ANOTHER",
           @"ANYTHING",
           @"AROUND",
           @"ART",
           @"AUNT",
           @"BALLOON",
           @"BARK",
           @"BARN",
           @"BASKET",
           @"BEACH",
           @"BEAR",
           @"BECAUSE",
           @"BECOME",
           @"BEGAN",
           @"BEGIN",
           @"BEHIND",
           @"BELIEVE",
           @"BELOW",
           @"BELT",
           @"BETTER",
           @"BIRTHDAY",
           @"BODY",
           @"BONES",
           @"BORN",
           @"BOUGHT",
           @"BREAD",
           @"BRIGHT",
           @"BROKE",
           @"BROUGHT",
           @"BUSY",
           @"CABIN",
           @"CAGE",
           @"CAMP",
           @"CAN'T",
           @"CARE",
           @"CARRY",
           @"CATCH",
           @"CATTLE",
           @"CAVE",
           @"CHILDREN",
           @"CLASS",
           @"CLOSE",
           @"CLOTH",
           @"COAL",
           @"COLOR",
           @"CORNER",
           @"COTTON",
           @"COVER",
           @"DARK",
           @"DESERT",
           @"DIDN'T",
           @"DINNER",
           @"DISHES",
           @"DOES",
           @"DONE",
           @"DON'T",
           @"DRAGON",
           @"DRAW",
           @"DREAM",
           @"DRINK",
           @"EARLY",
           @"EARTH",
           @"EAST",
           @"EIGHT",
           @"XSEVEN",
           @"EVER",
           @"EVERY",
           @"EVERYONE",
           @"EVERYTHING",
           @"EYES",
           @"FACE",
           @"FAMILY",
           @"FEELING",
           @"FELT",
           @"FEW",
           @"FIGHT",
           @"FISHING",
           @"FLOWER",
           @"FLYING",
           @"FOLLOW",
           @"FOREST",
           @"FORGOT",
           @"FORM",
           @"FOUND",
           @"FOURTH",
           @"FREE",
           @"FRIDAY",
           @"FRIEND",
           @"FRONT",
           @"GETTING",
           @"GIVEN",
           @"GRANDMOTHER",
           @"GREAT",
           @"GREW",
           @"GROUND",
           @"GUESS",
           @"HAIR",
           @"HALF",
           @"HAVING",
           @"HEAD",
           @"HEARD",
           @"HE'S",
           @"HEAT",
           @"HELLO",
           @"HIGH",
           @"HIMSELF",
           @"HOUR",
           @"HUNDRED",
           @"HURRY",
           @"HURT",
           @"INCHES",
           @"ISN'T",
           @"IT'S",
           @"KEPT",
           @"KIDS",
           @"KIND",
           @"KITTEN",
           @"KNEW",
           @"KNIFE",
           @"LADY",
           @"LARGE",
           @"LARGEST",
           @"LATER",
           @"LEARN",
           @"LEAVE",
           @"LET'S",
           @"LETTER",
           @"LIFE",
           @"LIST",
           @"LIVING",
           @"LOVELY",
           @"LOVING",
           @"LUNCH",
           @"MAIL",
           @"MAKING",
           @"MAYBE",
           @"MEAN",
           @"MERRY",
           @"MIGHT",
           @"MIND",
           @"MONEY",
           @"MONTH",
           @"MORNING",
           @"MOUSE",
           @"MOUTH",
           @"MUSIC",
           @"NEAR",
           @"NEARLY",
           @"NEVER",
           @"NEWS",
           @"NOISE",
           @"NOTHING",
           @"NUMBER",
           @"CLOCK",
           @"OFTEN",
           @"OIL",
           @"ONCE",
           @"ORANGE",
           @"ORDER",
           @"OWN",
           @"PAIR",
           @"PAINT",
           @"PAPER",
           @"PARTY",
           @"PASS",
           @"PAST",
           @"PENNY",
           @"PEOPLE",
           @"PERSON",
           @"PICTURE",
           @"PLACE",
           @"PLAN",
           @"PLANE",
           @"PLEASE",
           @"POCKET",
           @"POINT",
           @"POOR",
           @"RACE",
           @"REACH",
           @"READING",
           @"READY",
           @"REAL",
           @"RICH",
           @"RIGHT",
           @"RIVER",
           @"ROCKET",
           @"RODE",
           @"ROUND",
           @"RULE",
           @"RUNNING",
           @"SALT",
           @"SAYS",
           @"SENDING",
           @"SENT",
           @"SEVENTH",
           @"SEW",
           @"SHALL",
           @"SHORT",
           @"SHOT",
           @"SHOULD",
           @"SIGHT",
           @"SISTER",
           @"SITTING",
           @"SIXTH",
           @"SLED",
           @"SMOKE",
           @"SOAP",
           @"SOMEONE",
           @"SOMETHING",
           @"SOMETIME",
           @"SONG",
           @"SORRY",
           @"SOUND",
           @"SOUTH",
           @"SPACE",
           @"SPELLING",
           @"SPENT",
           @"SPORT",
           @"SPRING",
           @"STAIRS",
           @"STAND",
           @"STATE",
           @"STEP",
           @"STICK",
           @"STOOD",
           @"STOPPED",
           @"STOVE",
           @"STREET",
           @"STRONG",
           @"STUDY",
           @"SUCH",
           @"SUGAR",
           @"SUMMER",
           @"SUNDAY",
           @"SUPPER",
           @"TABLE",
           @"TAKEN",
           @"TAKING",
           @"TALKING",
           @"TEACHER",
           @"TEAM",
           @"TEETH",
           @"TENTH",
           @"THAT'S",
           @"THEIR",
           @"THESE",
           @"THINKING",
           @"THIRD",
           @"THOSE",
           @"THOUGHT",
           @"THROW",
           @"TONIGHT",
           @"TRADE",
           @"TRICK",
           @"TRIP",
           @"TRYING",
           @"TURN",
           @"TWELVE",
           @"TWENTY",
           @"UNCLE",
           @"UNDER",
           @"UPON",
           @"WAGON",
           @"WAIT",
           @"WALKING",
           @"WASN'T",
           @"WATCH",
           @"WATER",
           @"WEATHER",
           @"WE'RE",
           @"WEST",
           @"WHEAT",
           @"WHERE",
           @"WHICH",
           @"WIFE",
           @"WILD",
           @"WIN",
           @"WINDOW",
           @"WINTER",
           @"WITHOUT",
           @"WOMAN",
           @"WON",
           @"WON'T",
           @"WOOL",
           @"WORD",
           @"WORKING",
           @"WORLD",
           @"WOULD",
           @"WRITE",
           @"WRONG",
           @"YARD",
           @"YEAR",
           @"YESTERDAY",
           @"ACROSS",
           @"AGAINST",
           @"ANSWER",
           @"AWHILE",
           @"BETWEEN",
           @"BOARD",
           @"BOTTOM",
           @"BREAKFAST",
           @"BROKEN",
           @"BUILD",
           @"BUILDING",
           @"BUILT",
           @"CAPTAIN",
           @"CARRIED",
           @"CAUGHT",
           @"CHARGE",
           @"CHICKEN",
           @"CIRCUS",
           @"CITIES",
           @"CLOTHES",
           @"COMPANY",
           @"COULDN'T",
           @"COUNTRY",
           @"DISCOVER",
           @"DOCTOR",
           @"DOESN'T",
           @"DOLLAR",
           @"DURING",
           @"EIGHTH",
           @"ELSE",
           @"ENJOY",
           @"ENOUGH",
           @"EVERYBODY",
           @"EXAMPLE",
           @"EXCEPT",
           @"EXCUSE",
           @"FIELD",
           @"FIFTH",
           @"FINISH",
           @"FOLLOWING",
           @"GOOD-BY",
           @"GROUP",
           @"HAPPENED*",
           @"HARDEN",
           @"HAVEN'T",
           @"HEAVY",
           @"HELD",
           @"HOSPITAL",
           @"IDEA",
           @"INSTEAD",
           @"KNOWN",
           @"LAUGH",
           @"MIDDLE",
           @"MINUTE",
           @"MOUNTAIN",
           @"NINTH",
           @"OCEAN",
           @"OFFICE",
           @"PARENT",
           @"PEANUT",
           @"PENCIL",
           @"PICNIC",
           @"POLICE",
           @"PRETTY",
           @"PRIZE",
           @"QUITE",
           @"RADIO",
           @"RAISE",
           @"REALLY",
           @"REASON",
           @"REMEMBER",
           @"RETURN",
           @"SATURDAY",
           @"SCARE",
           @"SECOND",
           @"SINCE",
           @"SLOWLY",
           @"STORIES",
           @"STUDENT",
           @"SUDDEN",
           @"SUIT",
           @"SURE",
           @"SWIMMING",
           @"THOUGH",
           @"THREW",
           @"TIRED",
           @"TOGETHER",
           @"TOMORROW",
           @"TOWARD",
           @"TRIED",
           @"TROUBLE",
           @"TRULY",
           @"TURTLE",
           @"UNTIL",
           @"VILLAGE",
           @"VISIT",
           @"WEAR",
           @"WE'LL",
           @"WHOLE",
           @"WHOSE",
           @"WOMEN",
           @"WOULDN'T",
           @"WRITING",
           @"WRITTEN",
           @"WROTE",
           @"YELL",
           @"YOUNG",
           @"ALTHOUGH",
           @"AMERICA",
           @"AMONG",
           @"ARRIVE",
           @"ATTENTION",
           @"BEAUTIFUL",
           @"COUNTRIES",
           @"COURSE",
           @"COUSIN",
           @"DECIDE",
           @"DIFFERENT*",
           @"EVENING",
           @"FAVORITE",
           @"FINALLY",
           @"FUTURE",
           @"HAPPIEST",
           @"HAPPINESS",
           @"IMPORTANT",
           @"INTEREST",
           @"PIECE",
           @"PLANET",
           @"PRESENT",
           @"PRESIDENT",
           @"PRINCIPAL",
           @"PROBABLY",
           @"PROBLEM",
           @"RECEIVE",
           @"SENTENCE",
           @"SEVERAL",
           @"SPECIAL",
           @"SUDDENLY",
           @"SUPPOSE",
           @"SURELY",
           @"SURPRISE",
           @"THROUGH",
           @"USUALLY",
           @"MONDAY",
           @"TUESDAY",
           @"WEDNESDAY",
           @"THURSDAY",
           @"SUNDAY",
           @"JANUARY",
           @"FEBRUARY",
           @"MARCH",
           @"APRIL",
           @"MAY",
           @"JUNE",
           @"JULY",
           @"AUGUST",
           @"SEPTEMBER",
           @"OCTOBER",
           @"NOVEMBER",
           @"DECEMBER",
           ];
};


- (BOOL) shouldAutorotate  {
  return YES;
}




- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */



@end

//
//  ViewController.m
//  Visa-Takehome
//
//  Created by Kartik Krishnanand on 2/17/18.
//  Copyright © 2018 Kartik Krishnanand. All rights reserved.
//

#import "ViewController.h"
#import <Foundation/Foundation.h>

@interface ViewController ()<UITextFieldDelegate>
@property (strong, nonatomic) IBOutlet UITextField *stockField;
@property (strong, nonatomic) IBOutlet UIButton *submitButton;
@property (strong, nonatomic) IBOutlet UITextView *stockView;
@property (strong, nonatomic) IBOutlet UILabel *enterSymbolLabel;

@end

@implementation ViewController


-(void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.stockField becomeFirstResponder];
    [self.stockField setClearsOnBeginEditing:YES];
}

- (IBAction)loadStockPrices:(id)sender {
    [self.stockField resignFirstResponder];
    [self getStockInformation];
}

// Returns date and time for EST time zone.
-(NSArray *)formatCurrentDateTimeForEST { //Gets current date each time it's fired.
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSTimeZone *localTimeZone = [NSTimeZone timeZoneWithAbbreviation:@"EST"];
    NSLocale *posix = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [dateFormatter setLocale:posix];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    [dateFormatter setTimeZone:localTimeZone];
    
    NSDateFormatter *timeFormatter = [[NSDateFormatter alloc] init];
    [timeFormatter setLocale:posix];
    [timeFormatter setDateFormat:@"HH:mm:ss"];
    [timeFormatter setTimeZone:localTimeZone];
    return @[dateFormatter, timeFormatter];
}

// Determine the best date and time to the appropriate date.
// If the time is after hours, we try to return the today's date string.
// If the time is before hours, then we try to return the yesterday's date string.
// The implementation assumes that the start time is 10 AM EST, and end time is 4 PM EST.
// The outuput is an array of suitable time, and the function series.
-(NSArray*) getSuitableDate {
    NSArray* formatters = [self formatCurrentDateTimeForEST];
    NSDate* now = [NSDate date];
    NSDateFormatter* timeFormatter =
        (NSDateFormatter*) [formatters objectAtIndex:1];
    NSDateFormatter* dateFormatter = (NSDateFormatter*) [formatters objectAtIndex:0];
    NSString *time = [timeFormatter stringFromDate:now];
    int hour = [time substringWithRange:NSMakeRange(0, 2)].intValue;
    if (hour >= 16) {
        // Greater  pm EST.
        return @[[dateFormatter stringFromDate:now], @"TIME_SERIES_DAILY"];
    } else if (hour >= 10){
        return @[[dateFormatter stringFromDate:now], @"TIME_SERIES_INTRADAY"];
    } else  {
        return @[
            [dateFormatter stringFromDate:[now dateByAddingTimeInterval:-1 * 60 * 60 * 24]],
            @"TIME_SERIES_DAILY"];
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [[event allTouches] anyObject];
    if ([self.stockField isFirstResponder] && [touch view] != self.stockField) {
        [self.stockField resignFirstResponder];
    }
    [super touchesBegan:touches withEvent:event];
}

-(void) getStockInformation {
    NSArray* suitableDate = [self getSuitableDate];
    NSString* date = [suitableDate firstObject];
    NSString* freq = [suitableDate objectAtIndex:1];
    NSString* url =
        [NSString stringWithFormat:@"https://www.alphavantage.co/query?function=%@&symbol=%@&apikey=AU8JM02UC0OUR0Q4&interval=1min",
        freq, self.stockField.text];
    NSURL* nsUrl = [[NSURL alloc] initWithString:url];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:nsUrl];
    [request setHTTPMethod:@"GET"];
    [request setValue:@"application/json;charset=UTF-8" forHTTPHeaderField:@"Content-type"];
    NSURLSession *session = [NSURLSession sharedSession];
    // dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSURLSessionDataTask * dataTask = [session dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSError* err;
            // If response JSON starts with {}, it represents dictionary
            NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&err];
            NSArray* freqBreakDown = [freq componentsSeparatedByString: @"_"];
            
            NSString* key =
              [[[NSString stringWithFormat:@"%@ %@", [freqBreakDown firstObject], [freqBreakDown objectAtIndex:1]] lowercaseString] capitalizedString];
            for (NSString* dictKey in dict) {
                if ([dictKey hasPrefix:key]) {
                    NSSortDescriptor *sd = [[NSSortDescriptor alloc] initWithKey:nil ascending:NO];
                    NSArray* sortedArray =
                        [[[dict valueForKey:dictKey] allKeys] sortedArrayUsingDescriptors:@[sd]];
                    NSDictionary* allDict = [[dict valueForKey:dictKey] valueForKey:[sortedArray firstObject]];
                    NSString* text =
                        [NSString stringWithFormat:@"Open Value = %@ \nHigh Value = %@ \nLow Value = %@ \nLatest Value = %@\n", [allDict valueForKey:@"1. open"], [allDict valueForKey:@"2. high"], [allDict valueForKey:@"3. low"], [allDict valueForKey:@"4. close"]];
                    dispatch_queue_t myQueue = dispatch_queue_create("My Queue",NULL);
                    dispatch_async(myQueue, ^{
                        dispatch_async(dispatch_get_main_queue(), ^{
                            self.stockView.text = text;
                        });
                    });
                }
            }
    }];
    [dataTask resume];
    // dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}
@end
